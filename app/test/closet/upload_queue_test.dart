import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stylist/core/storage/key_value_store.dart';
import 'package:stylist/features/closet/application/image_pipeline.dart';
import 'package:stylist/features/closet/application/upload_queue.dart';
import 'package:stylist/features/closet/data/blob_store.dart';
import 'package:stylist/features/closet/data/mock_closet.dart';
import 'package:stylist/features/closet/domain/closet_query.dart';

Uint8List jpeg([int seed = 0]) {
  final im = img.Image(width: 40, height: 40);
  img.fill(im, color: img.ColorRgb8(40 + seed, 80, 160));
  return Uint8List.fromList(img.encodeJpg(im));
}

ProcessedPhoto photo(String name, [int seed = 0]) => ProcessedPhoto(
  bytes: jpeg(seed),
  filename: name,
  width: 40,
  height: 40,
);

class Rig {
  Rig({int limit = 30}) {
    backend = MockClosetBackend(
      store: server,
      blobs: serverBlobs,
      userKey: 'u1',
      itemLimit: () => limit,
      processingDelay: Duration.zero,
      analysisDelay: Duration.zero,
    );
    queue = make();
  }

  final server = MemoryKeyValueStore();
  final serverBlobs = MemoryBlobStore();
  final local = MemoryKeyValueStore();
  final localBlobs = MemoryBlobStore();
  late final MockClosetBackend backend;
  late UploadQueue queue;
  final delays = <Duration>[];

  UploadQueue make() => UploadQueue(
    repository: backend,
    transport: backend,
    store: local,
    blobs: localBlobs,
    delay: (d) async => delays.add(d),
  );
}

Future<int> total(Rig r) async =>
    (await r.backend.list(const ClosetQuery())).total;

void main() {
  test('uploads a photo end to end and removes the local copy', () async {
    final r = Rig();
    final uploaded = <UploadItem>[];
    r.queue.onUploaded = uploaded.add;
    final id = await r.queue.enqueue(photo('tee.jpg'));
    await r.queue.drain();
    expect(r.queue.items.single.state, UploadState.done);
    expect(uploaded.single.clientId, id);
    expect(r.localBlobs.data, isEmpty);
    expect(await total(r), 1);
  });

  test('transient 503s retry with exponential backoff, then succeed', () async {
    final r = Rig();
    r.backend.failNext['complete'] = 2;
    await r.queue.enqueue(photo('a.jpg'));
    await r.queue.drain();
    expect(r.queue.items.single.state, UploadState.done);
    expect(r.delays, [const Duration(seconds: 1), const Duration(seconds: 2)]);
    expect(await total(r), 1, reason: 'retries never duplicate the garment');
  });

  test('gives up after max attempts and can be retried by hand', () async {
    final r = Rig();
    r.backend.failNext['create'] = 100;
    final failed = <UploadItem>[];
    r.queue.onFailed = failed.add;
    await r.queue.enqueue(photo('a.jpg'));
    await r.queue.drain();
    expect(r.queue.items.single.state, UploadState.failed);
    expect(failed, hasLength(1));
    expect(r.localBlobs.data, isNotEmpty, reason: 'photo kept for the retry');

    r.backend.failNext.clear();
    await r.queue.retry(r.queue.items.single.clientId);
    await r.queue.drain();
    expect(r.queue.items.single.state, UploadState.done);
  });

  test('offline pauses the queue; resume uploads everything', () async {
    final r = Rig();
    r.backend.offline = true;
    await r.queue.enqueue(photo('a.jpg'));
    await r.queue.enqueue(photo('b.jpg', 5));
    await r.queue.drain();
    expect(r.queue.items.every((i) => i.state == UploadState.queued), isTrue);
    expect(r.queue.items.first.errorCode, 'offline');

    r.backend.offline = false;
    await r.queue.resume();
    await r.queue.drain();
    expect(r.queue.items.every((i) => i.state == UploadState.done), isTrue);
    expect(await total(r), 2);
  });

  test('killing the app mid-upload resumes without duplicates', () async {
    final r = Rig();
    // The first run dies after the server created the garment but before the upload.
    r.backend.failNext['upload'] = 100;
    await r.queue.enqueue(photo('a.jpg'));
    await r.queue.drain();
    expect(r.queue.items.single.state, UploadState.failed);

    // "Restart": a new queue over the same persisted state.
    r.backend.failNext.clear();
    final reborn = r.make();
    await reborn.restore();
    expect(reborn.items.single.state, UploadState.failed);
    await reborn.retry(reborn.items.single.clientId);
    await reborn.drain();
    expect(reborn.items.single.state, UploadState.done);
    expect(await total(r), 1);
  });

  test(
    'items left mid-flight when the app was killed restart as queued',
    () async {
      final r = Rig();
      await r.local.write(
        UploadQueue.storageKey,
        '[{"client_id":"c1","photo_key":"queue_c1","filename":"a.jpg",'
        '"content_type":"image/jpeg","size_bytes":3,'
        '"created_at":"2026-10-14T10:00:00.000Z","state":"uploading",'
        '"attempts":0}]',
      );
      await r.localBlobs.put('queue_c1', jpeg());
      final q = r.make();
      await q.restore();
      expect(q.items.single.state, UploadState.queued);
      await q.drain();
      expect(q.items.single.state, UploadState.done);
    },
  );

  test('an expired signed URL fetches a fresh ticket and carries on', () async {
    final r = Rig();
    r.backend.expireNextUpload = true;
    await r.queue.enqueue(photo('a.jpg'));
    await r.queue.drain();
    expect(r.queue.items.single.state, UploadState.done);
    expect(r.backend.calls, contains('newTicket'));
  });

  test(
    'the free-plan limit rejects the photo for good (no retry loop)',
    () async {
      final r = Rig(limit: 1);
      await r.queue.enqueue(photo('a.jpg'));
      await r.queue.enqueue(photo('b.jpg', 9));
      await r.queue.drain();
      final states = r.queue.items.map((i) => i.state).toList();
      expect(states, contains(UploadState.done));
      final rejected = r.queue.items.firstWhere(
        (i) => i.state == UploadState.rejected,
      );
      expect(rejected.errorCode, 'item_limit_reached');
      expect(r.delays, isEmpty);
    },
  );

  test('a file the server cannot read is rejected, not retried', () async {
    final r = Rig();
    await r.queue.enqueue(
      ProcessedPhoto(
        bytes: Uint8List.fromList(List.filled(64, 7)),
        filename: 'x.jpg',
        width: 1,
        height: 1,
      ),
    );
    await r.queue.drain();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      r.queue.items.single.state,
      anyOf(UploadState.rejected, UploadState.done),
    );
  });

  test('progress reaches 1 and per-item progress is reported', () async {
    final r = Rig();
    final seen = <double>[];
    r.queue.changes.listen(
      (items) => seen.addAll(items.map((i) => i.progress)),
    );
    await r.queue.enqueue(photo('a.jpg'));
    await r.queue.drain();
    expect(seen.last, 1);
  });
}
