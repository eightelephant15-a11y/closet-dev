import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stylist/core/network/api_exception.dart';
import 'package:stylist/core/storage/key_value_store.dart';
import 'package:stylist/features/closet/application/image_pipeline.dart';
import 'package:stylist/features/closet/data/blob_store.dart';
import 'package:stylist/features/closet/domain/garment.dart';
import 'package:stylist/features/closet/domain/garment_repository.dart';
import 'package:uuid/uuid.dart';

enum UploadState {
  /// Waiting for its turn (or for the network).
  queued,

  /// Creating the garment record on the server.
  creating,
  uploading,

  /// Telling the server the upload is finished.
  completing,

  /// Uploaded; the server is processing and analysing it.
  done,

  /// Gave up after retries; the user can retry.
  failed,

  /// The server refused it for good (wrong file type, too big, item limit).
  rejected,
}

@immutable
class UploadItem {
  const UploadItem({
    required this.clientId,
    required this.photoKey,
    required this.filename,
    required this.contentType,
    required this.sizeBytes,
    required this.createdAt,
    this.state = UploadState.queued,
    this.attempts = 0,
    this.garmentId,
    this.imageId,
    this.progress = 0,
    this.errorCode,
    this.batchId,
  });

  factory UploadItem.fromJson(Map<String, dynamic> j) => UploadItem(
    clientId: j['client_id'] as String,
    photoKey: j['photo_key'] as String,
    filename: j['filename'] as String,
    contentType: j['content_type'] as String,
    sizeBytes: j['size_bytes'] as int,
    createdAt: DateTime.parse(j['created_at'] as String),
    state: UploadState.values.byName(j['state'] as String),
    attempts: j['attempts'] as int? ?? 0,
    garmentId: j['garment_id'] as String?,
    imageId: j['image_id'] as String?,
    errorCode: j['error_code'] as String?,
    batchId: j['batch_id'] as String?,
    progress: (j['state'] == 'done') ? 1 : 0,
  );

  /// Doubles as the idempotency key: a retry (or a restart mid-flight) never creates a second garment.
  final String clientId;
  final String photoKey;
  final String filename;
  final String contentType;
  final int sizeBytes;
  final DateTime createdAt;
  final UploadState state;
  final int attempts;
  final String? garmentId;
  final String? imageId;

  /// 0..1 of the photo bytes sent (not persisted).
  final double progress;
  final String? errorCode;
  final String? batchId;

  bool get isActive => switch (state) {
    UploadState.queued ||
    UploadState.creating ||
    UploadState.uploading ||
    UploadState.completing => true,
    _ => false,
  };

  UploadItem copyWith({
    UploadState? state,
    int? attempts,
    String? garmentId,
    String? imageId,
    double? progress,
    String? errorCode,
    bool clearError = false,
  }) => UploadItem(
    clientId: clientId,
    photoKey: photoKey,
    filename: filename,
    contentType: contentType,
    sizeBytes: sizeBytes,
    createdAt: createdAt,
    batchId: batchId,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    garmentId: garmentId ?? this.garmentId,
    imageId: imageId ?? this.imageId,
    progress: progress ?? this.progress,
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
  );

  Map<String, dynamic> toJson() => {
    'client_id': clientId,
    'photo_key': photoKey,
    'filename': filename,
    'content_type': contentType,
    'size_bytes': sizeBytes,
    'created_at': createdAt.toIso8601String(),
    'state': state.name,
    'attempts': attempts,
    'garment_id': garmentId,
    'image_id': imageId,
    'error_code': errorCode,
    'batch_id': batchId,
  };
}

/// Exponential backoff with a cap: 1s, 2s, 4s, 8s, 16s...
Duration defaultBackoff(int attempt) =>
    Duration(seconds: (1 << (attempt - 1)).clamp(1, 30));

/// Photos waiting to reach the server.
///
/// * Persisted (state in the key-value store, photo bytes in the blob store), so killing the app mid-upload
///   resumes where it was.
/// * Idempotent: `clientId` is generated once per photo and sent on create; ticket expiry fetches a new
///   ticket for the same image; "complete" is safe to repeat.
/// * Retries transient failures with backoff up to [maxAttempts]; offline pauses the queue until [resume].
class UploadQueue {
  UploadQueue({
    required this.repository,
    required this.transport,
    required this.store,
    required this.blobs,
    this.maxAttempts = 5,
    this.concurrency = 2,
    this.backoff = defaultBackoff,
    Future<void> Function(Duration)? delay,
    DateTime Function()? clock,
    String Function()? newId,
  }) : _delay = delay ?? Future<void>.delayed,
       _clock = clock ?? DateTime.now,
       _newId = newId ?? (() => const Uuid().v4());

  static const storageKey = 'upload_queue_v1';

  final GarmentRepository repository;
  final UploadTransport transport;
  final KeyValueStore store;
  final BlobStore blobs;
  final int maxAttempts;
  final int concurrency;
  final Duration Function(int attempt) backoff;
  final Future<void> Function(Duration) _delay;
  final DateTime Function() _clock;
  final String Function() _newId;

  /// Called once per photo when it has been uploaded and handed to the server.
  void Function(UploadItem item)? onUploaded;

  /// Called when a photo is refused permanently or runs out of retries.
  void Function(UploadItem item)? onFailed;

  final List<UploadItem> _items = [];
  final _changes = StreamController<List<UploadItem>>.broadcast();
  final Set<String> _running = {};
  final Set<String> _staleTicket = {};
  bool _paused = false;
  bool _loaded = false;
  Completer<void>? _idle;

  List<UploadItem> get items => List.unmodifiable(_items);
  Stream<List<UploadItem>> get changes => _changes.stream;
  bool get hasActive => _items.any((i) => i.isActive);

  /// Loads persisted items. Anything that was mid-flight goes back to "queued".
  Future<void> restore() async {
    if (_loaded) return;
    _loaded = true;
    final raw = store.read(storageKey);
    if (raw == null) return;
    for (final e in jsonDecode(raw) as List) {
      final item = UploadItem.fromJson((e as Map).cast<String, dynamic>());
      _items.add(
        item.isActive ? item.copyWith(state: UploadState.queued) : item,
      );
    }
    _emit(save: false);
  }

  /// Adds a processed photo and starts uploading. Returns the client id.
  Future<String> enqueue(ProcessedPhoto photo, {String? batchId}) async {
    await restore();
    final id = _newId();
    final key = 'queue_$id';
    await blobs.put(key, photo.bytes);
    _items.add(
      UploadItem(
        clientId: id,
        photoKey: key,
        filename: photo.filename,
        contentType: photo.contentType,
        sizeBytes: photo.bytes.length,
        createdAt: _clock().toUtc(),
        batchId: batchId,
      ),
    );
    _emit();
    unawaited(_pump());
    return id;
  }

  /// Network is back (or the user pressed retry-all): try everything that is waiting.
  Future<void> resume() async {
    await restore();
    _paused = false;
    await _pump();
  }

  /// Retry one failed or rejected-by-limit photo.
  Future<void> retry(String clientId) async {
    final i = _index(clientId);
    if (i < 0) return;
    _items[i] = _items[i].copyWith(
      state: UploadState.queued,
      attempts: 0,
      clearError: true,
    );
    _emit();
    _paused = false;
    await _pump();
  }

  /// Drop a photo (and its bytes) from the queue.
  Future<void> remove(String clientId) async {
    final i = _index(clientId);
    if (i < 0) return;
    final item = _items.removeAt(i);
    await blobs.delete(item.photoKey);
    _emit();
  }

  /// Drops everything, including photos not uploaded yet (sign-out / account deletion).
  Future<void> clearAll() async {
    await restore();
    for (final i in _items) {
      await blobs.delete(i.photoKey);
    }
    _items.clear();
    _paused = false;
    await store.remove(storageKey);
    if (!_changes.isClosed) _changes.add(items);
  }

  /// Forget finished uploads from the list.
  Future<void> clearDone() async {
    _items.removeWhere((i) => i.state == UploadState.done);
    _emit();
  }

  /// Completes when nothing is runnable any more (tests and "save and close").
  Future<void> drain() async {
    await restore();
    await _pump();
    while (_running.isNotEmpty) {
      await (_idle ??= Completer<void>()).future;
    }
  }

  int _index(String id) => _items.indexWhere((i) => i.clientId == id);

  void _emit({bool save = true}) {
    if (save) {
      unawaited(
        store.write(
          storageKey,
          jsonEncode([for (final i in _items) i.toJson()]),
        ),
      );
    }
    if (!_changes.isClosed) _changes.add(items);
  }

  void _update(String id, UploadItem Function(UploadItem) f) {
    final i = _index(id);
    if (i < 0) return;
    _items[i] = f(_items[i]);
    _emit();
  }

  Future<void> _pump() async {
    if (_paused) return;
    for (final item in List.of(_items)) {
      if (_running.length >= concurrency) break;
      if (item.state != UploadState.queued ||
          _running.contains(item.clientId)) {
        continue;
      }
      _running.add(item.clientId);
      unawaited(
        _run(item.clientId).whenComplete(() {
          _running.remove(item.clientId);
          if (_running.isEmpty) {
            _idle?.complete();
            _idle = null;
          }
          unawaited(_pump());
        }),
      );
    }
  }

  Future<void> _run(String clientId) async {
    while (true) {
      final i = _index(clientId);
      if (i < 0) return;
      final item = _items[i];
      try {
        await _attempt(item);
        return;
      } on UploadTicketExpired {
        // Not a failure: the next attempt asks for a fresh ticket.
        _staleTicket.add(clientId);
        _update(clientId, (x) => x.copyWith(state: UploadState.queued));
        continue;
      } on ApiException catch (e) {
        if (e.isOffline) {
          // Pause; `resume()` restarts when connectivity returns.
          _paused = true;
          _update(
            clientId,
            (x) => x.copyWith(state: UploadState.queued, errorCode: 'offline'),
          );
          return;
        }
        final permanent = const {
          'unsupported_media',
          'file_too_large',
          'image_invalid',
          'item_limit_reached',
          'upload_missing_permanent',
        }.contains(e.code);
        if (permanent) {
          _update(
            clientId,
            (x) => x.copyWith(state: UploadState.rejected, errorCode: e.code),
          );
          _notifyFailed(clientId);
          return;
        }
        final attempts = item.attempts + 1;
        if (attempts >= maxAttempts) {
          _update(
            clientId,
            (x) => x.copyWith(
              state: UploadState.failed,
              attempts: attempts,
              errorCode: e.code,
            ),
          );
          _notifyFailed(clientId);
          return;
        }
        _update(
          clientId,
          (x) => x.copyWith(
            state: UploadState.queued,
            attempts: attempts,
            errorCode: e.code,
          ),
        );
        await _delay(backoff(attempts));
      }
    }
  }

  void _notifyFailed(String id) {
    final i = _index(id);
    if (i >= 0) onFailed?.call(_items[i]);
  }

  Future<void> _attempt(UploadItem start) async {
    final id = start.clientId;
    final bytes = await blobs.get(start.photoKey);
    if (bytes == null) {
      throw const ApiException(
        code: 'image_invalid',
        message: 'The saved photo is gone',
      );
    }
    // 1. create (idempotent on client id); a restart after this point re-reads the same garment
    _update(
      id,
      (x) => x.copyWith(state: UploadState.creating, clearError: true),
    );
    final created = await repository.create(
      NewGarment(
        clientId: id,
        contentType: start.contentType,
        filename: start.filename,
        sizeBytes: bytes.length,
      ),
    );
    final garmentId = created.garment.id;
    final imageId =
        created.ticket?.imageId ??
        created.garment.coverImageId ??
        start.imageId ??
        (created.garment.images.isEmpty
            ? null
            : created.garment.images.first.id);
    if (imageId == null) {
      throw const ApiException(code: 'image_invalid', message: 'No image slot');
    }
    _update(id, (x) => x.copyWith(garmentId: garmentId, imageId: imageId));

    // 2. upload straight to storage. A retry after a restart may have no ticket (the garment already
    // existed), so ask for a fresh one.
    final alreadyUploaded = created.garment.images.any(
      (im) => im.id == imageId && im.status != ImageStatus.awaitingUpload,
    );
    if (!alreadyUploaded) {
      final stale = _staleTicket.remove(id);
      final ticket =
          created.ticket == null || stale || created.ticket!.isExpired()
          ? await repository.newTicket(garmentId, imageId)
          : created.ticket!;
      _update(id, (x) => x.copyWith(state: UploadState.uploading));
      await transport.upload(
        ticket,
        bytes,
        onProgress: (sent, total) {
          if (total > 0) _update(id, (x) => x.copyWith(progress: sent / total));
        },
      );
    }

    // 3. complete (safe to repeat)
    _update(id, (x) => x.copyWith(state: UploadState.completing));
    await repository.complete(garmentId, imageId);
    await blobs.delete(start.photoKey);
    _update(
      id,
      (x) => x.copyWith(state: UploadState.done, progress: 1, clearError: true),
    );
    final i = _index(id);
    if (i >= 0) onUploaded?.call(_items[i]);
  }

  Future<void> dispose() => _changes.close();
}
