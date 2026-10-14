import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:image/image.dart' as img;
import 'package:stylist/core/network/api_exception.dart';
import 'package:stylist/core/storage/key_value_store.dart';
import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/closet/data/blob_store.dart';
import 'package:stylist/features/closet/data/fake_vision.dart';
import 'package:stylist/features/closet/data/sample_garments.dart';
import 'package:stylist/features/closet/domain/closet_query.dart';
import 'package:stylist/features/closet/domain/garment.dart';
import 'package:stylist/features/closet/domain/garment_repository.dart';
import 'package:stylist/features/closet/domain/taxonomy.dart';
import 'package:uuid/uuid.dart';

typedef Json = Map<String, dynamic>;

/// The closet API and object storage, reproduced in-process for mock mode and tests: same states and
/// error codes as the real server (idempotent create, signed-ticket upload, processing -> analysing -> done,
/// item limit, validation), persisted locally so a restart resumes mid-flight.
class MockClosetBackend implements GarmentRepository, UploadTransport {
  MockClosetBackend({
    required this.store,
    required this.blobs,
    required this.userKey,
    required this.itemLimit,
    this.bulkEnabled = _always,
    this.department = _none,
    this.processingDelay = const Duration(milliseconds: 600),
    this.analysisDelay = const Duration(milliseconds: 1200),
    this.ticketLifetime = const Duration(minutes: 15),
    this.maxBytes = 12 * 1024 * 1024,
    DateTime Function()? clock,
    this.vision = const FakeVision(),
  }) : _clock = clock ?? DateTime.now;

  static bool _always() => true;
  static ClothingDepartment? _none() => null;

  final KeyValueStore store;
  final BlobStore blobs;
  final String userKey;
  final int Function() itemLimit;
  final bool Function() bulkEnabled;
  final ClothingDepartment? Function() department;
  final Duration processingDelay;
  final Duration analysisDelay;
  final Duration ticketLifetime;
  final int maxBytes;
  final FakeVision vision;
  final DateTime Function() _clock;

  /// Simulate no connectivity.
  bool offline = false;

  /// The next upload finds its signed URL expired (403).
  bool expireNextUpload = false;

  /// Make the next N calls to these methods fail with a 503 (retry tests).
  final Map<String, int> failNext = {};

  /// Records every call (tests assert on idempotency and retries).
  final List<String> calls = [];

  List<Json>? _cache;
  final Set<String> _scheduled = {};
  String get _key => 'mock_server_garments_$userKey';

  // ---- persistence -----------------------------------------------------------------------------

  List<Json> get _all {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = store.read(_key);
    final list = raw == null
        ? <Json>[]
        : [
            for (final e in jsonDecode(raw) as List)
              (e as Map).cast<String, dynamic>(),
          ];
    _cache = list;
    list.forEach(_resume);
    return list;
  }

  void _save() => unawaited(store.write(_key, jsonEncode(_all)));

  void _enter(String method) {
    calls.add(method);
    if (offline) throw const ApiException.offline();
    final left = failNext[method] ?? 0;
    if (left > 0) {
      failNext[method] = left - 1;
      throw const ApiException(
        code: 'http_503',
        message: 'unavailable',
        statusCode: 503,
      );
    }
  }

  Json _find(String id) => _all.firstWhere(
    (g) => g['id'] == id,
    orElse: () => throw const ApiException(
      code: 'garment_not_found',
      message: 'Garment not found',
      statusCode: 404,
    ),
  );

  Json _image(Json g, String imageId) =>
      (g['images'] as List).cast<Json>().firstWhere(
        (i) => i['id'] == imageId,
        orElse: () => throw const ApiException(
          code: 'garment_not_found',
          message: 'Garment not found',
          statusCode: 404,
        ),
      );

  // ---- reads -----------------------------------------------------------------------------------------------

  Garment _garment(Json g) =>
      Garment.fromApi(jsonDecode(jsonEncode(g)) as Json);

  @override
  Future<Garment> get(String id) async {
    _enter('get');
    return _garment(_find(id));
  }

  int get _used =>
      _all.where((g) => g['archived'] != true && g['is_sample'] != true).length;

  @override
  Future<Entitlements> entitlements() async {
    _enter('entitlements');
    return Entitlements(
      plan: 'free',
      limit: itemLimit(),
      used: _used,
      bulkEnabled: bulkEnabled(),
      bulkMax: 20,
    );
  }

  @override
  Future<ClosetSummary> summary() async {
    _enter('summary');
    final live = _all.where((g) => g['archived'] != true).toList();
    CategoryCounts counts(Iterable<Json> items) {
      final byCat = <String, int>{};
      final bySub = <String, int>{};
      for (final g in items) {
        final c = g['category'] as String?;
        final s = g['subcategory'] as String?;
        if (c != null) byCat[c] = (byCat[c] ?? 0) + 1;
        if (s != null) bySub[s] = (bySub[s] ?? 0) + 1;
      }
      return CategoryCounts(byCat, bySub);
    }

    return ClosetSummary(
      total: live.length,
      archived: _all.length - live.length,
      favorites: live.where((g) => g['favorite'] == true).length,
      needsReview: live
          .where((g) => g['reviewed'] != true && g['is_sample'] != true)
          .length,
      counts: counts(live),
      availableCounts: counts(
        live.where((g) => g['availability'] == 'available'),
      ),
      limit: itemLimit(),
      used: _used,
    );
  }

  bool _matches(Json g, ClosetQuery q) {
    switch (q.archived) {
      case ArchivedMode.exclude:
        if (g['archived'] == true) return false;
      case ArchivedMode.only:
        if (g['archived'] != true) return false;
      case ArchivedMode.include:
        break;
    }
    if (q.category != null && g['category'] != q.category) return false;
    if (q.subcategory != null && g['subcategory'] != q.subcategory) {
      return false;
    }
    if (q.color != null &&
        g['primary_color'] != q.color &&
        g['secondary_color'] != q.color) {
      return false;
    }
    if (q.season != null &&
        !((g['seasons'] as List?) ?? const []).contains(q.season)) {
      return false;
    }
    final f = g['formality'] as int?;
    if (q.formalityMin != null && (f ?? 0) < q.formalityMin!) return false;
    if (q.formalityMax != null && (f ?? 0) > q.formalityMax!) return false;
    if (q.favorite != null && (g['favorite'] == true) != q.favorite) {
      return false;
    }
    if (q.availability != null && g['availability'] != q.availability) {
      return false;
    }
    if (q.reviewed != null && (g['reviewed'] == true) != q.reviewed) {
      return false;
    }
    for (final raw
        in q.text
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty)) {
      final hay = [
        for (final k in [
          'category',
          'subcategory',
          'primary_color',
          'secondary_color',
          'pattern',
          'fit',
          'material',
        ])
          if (g[k] != null) '${g[k]} ${Taxonomy.instance.labels[g[k]] ?? ''}',
        for (final s in (g['seasons'] as List?) ?? const []) '$s',
        '${g['brand'] ?? ''} ${g['notes'] ?? ''}',
      ].join(' ').toLowerCase().replaceAll('_', ' ');
      if (!hay.contains(raw)) return false;
    }
    return true;
  }

  @override
  Future<GarmentPage> list(
    ClosetQuery query, {
    String? cursor,
    int limit = 40,
  }) async {
    _enter('list');
    final rows = _all.where((g) => _matches(g, query)).toList();
    int cmp(Json a, Json b) {
      switch (query.sort) {
        case ClosetSort.newest:
          return '${b['created_at']}${b['id']}'.compareTo(
            '${a['created_at']}${a['id']}',
          );
        case ClosetSort.oldest:
          return '${a['created_at']}${a['id']}'.compareTo(
            '${b['created_at']}${b['id']}',
          );
        case ClosetSort.recentlyEdited:
          return '${b['updated_at']}${b['id']}'.compareTo(
            '${a['updated_at']}${a['id']}',
          );
        case ClosetSort.formalityLow:
          final c = ((a['formality'] as int?) ?? 0).compareTo(
            (b['formality'] as int?) ?? 0,
          );
          return c != 0 ? c : '${a['id']}'.compareTo('${b['id']}');
        case ClosetSort.formalityHigh:
          final c = ((b['formality'] as int?) ?? 0).compareTo(
            (a['formality'] as int?) ?? 0,
          );
          return c != 0 ? c : '${b['id']}'.compareTo('${a['id']}');
      }
    }

    rows.sort(cmp);
    final start = cursor == null
        ? 0
        : int.parse(utf8.decode(base64Url.decode(cursor)));
    final end = (start + limit).clamp(0, rows.length);
    return GarmentPage(
      items: [for (final g in rows.sublist(start, end)) _summary(g)],
      total: rows.length,
      nextCursor: end < rows.length
          ? base64Url.encode(utf8.encode('$end'))
          : null,
    );
  }

  GarmentSummary _summary(Json g) {
    final images = (g['images'] as List).cast<Json>();
    final cover = images
        .where((i) => i['id'] == g['cover_image_id'])
        .firstOrNull;
    final ready = cover != null && cover['status'] == 'ready';
    return GarmentSummary.fromApi({
      ...g,
      'analysis_status': (g['analysis'] as Map)['status'],
      'low_confidence_fields': (g['analysis'] as Map)['low_confidence_fields'],
      'thumb_url': ready ? 'mock://blob/${cover['id']}/m' : null,
      'image_version': ready ? cover['id'] : null,
    });
  }

  // ---- create / upload ---------------------------------------------------------------------------------

  UploadTicket _ticket(String imageId) => UploadTicket(
    imageId: imageId,
    url: 'mock://upload/$imageId',
    method: 'PUT',
    headers: const {},
    fields: const {},
    expiresAt: _clock().toUtc().add(ticketLifetime),
    maxBytes: maxBytes,
  );

  Json _blank(NewGarment n) {
    final now = _clock().toUtc().toIso8601String();
    final gid = const Uuid().v4();
    final iid = const Uuid().v4();
    return {
      'id': gid,
      'client_id': n.clientId,
      'category': null,
      'subcategory': null,
      'primary_color': null,
      'secondary_color': null,
      'pattern': null,
      'formality': null,
      'seasons': null,
      'fit': null,
      'material': null,
      'brand': null,
      'notes': null,
      'favorite': false,
      'availability': 'available',
      'unavailable_until': null,
      'archived': false,
      'reviewed': false,
      'excluded_from_outfits': false,
      'is_sample': false,
      'sample_asset': null,
      'analysis': {
        'status': 'pending',
        'fields': null,
        'low_confidence_fields': <String>[],
        'provider': null,
        'model': null,
        'version': null,
        'taxonomy_version': 1,
      },
      'images': [
        {
          'id': iid,
          'status': 'awaiting_upload',
          'width': null,
          'height': null,
          'urls': <String, String?>{},
          'error': null,
          'filename': n.filename,
        },
      ],
      'cover_image_id': null,
      'created_at': now,
      'updated_at': now,
    };
  }

  CreatedGarment _created(Json g) {
    final waiting = (g['images'] as List)
        .cast<Json>()
        .where((i) => i['status'] == 'awaiting_upload')
        .firstOrNull;
    return CreatedGarment(
      _garment(g),
      waiting == null ? null : _ticket(waiting['id'] as String),
    );
  }

  void _checkRoom(int adding) {
    final remaining = itemLimit() - _used;
    if (remaining < adding) {
      throw ApiException(
        code: 'item_limit_reached',
        message: 'Your closet is full on the free plan.',
        statusCode: 403,
        details: {
          'limit': itemLimit(),
          'used': _used,
          'remaining': remaining < 0 ? 0 : remaining,
          'requested': adding,
          'plan': 'free',
        },
      );
    }
  }

  @override
  Future<CreatedGarment> create(NewGarment item) async {
    _enter('create');
    final existing = _all
        .where((g) => g['client_id'] == item.clientId)
        .firstOrNull;
    if (existing != null) return _created(existing);
    _checkRoom(1);
    if (item.sizeBytes != null && item.sizeBytes! > maxBytes) {
      throw const ApiException(
        code: 'file_too_large',
        message: 'That photo is too large.',
        statusCode: 413,
      );
    }
    final g = _blank(item);
    _all.add(g);
    _save();
    return _created(g);
  }

  @override
  Future<List<CreatedGarment>> bulkCreate(List<NewGarment> items) async {
    _enter('bulkCreate');
    if (!bulkEnabled()) {
      throw const ApiException(
        code: 'bulk_disabled',
        message: 'Adding several items at once is not available right now.',
        statusCode: 403,
      );
    }
    if (items.length > 20) {
      throw const ApiException(
        code: 'bulk_too_large',
        message: 'Add at most 20 items at a time.',
        statusCode: 422,
      );
    }
    final fresh = items
        .where((n) => !_all.any((g) => g['client_id'] == n.clientId))
        .toList();
    _checkRoom(fresh.length);
    final out = <CreatedGarment>[];
    for (final n in items) {
      final existing = _all
          .where((g) => g['client_id'] == n.clientId)
          .firstOrNull;
      if (existing != null) {
        out.add(_created(existing));
      } else {
        final g = _blank(n);
        _all.add(g);
        out.add(_created(g));
      }
    }
    _save();
    return out;
  }

  @override
  Future<UploadTicket> newTicket(String garmentId, String imageId) async {
    _enter('newTicket');
    final image = _image(_find(garmentId), imageId);
    if (image['status'] != 'awaiting_upload') {
      throw const ApiException(
        code: 'upload_already_completed',
        message: 'This photo was already uploaded',
        statusCode: 409,
      );
    }
    return _ticket(imageId);
  }

  @override
  Future<void> upload(
    UploadTicket ticket,
    Uint8List bytes, {
    void Function(int sent, int total)? onProgress,
  }) async {
    calls.add('upload');
    if (offline) throw const ApiException.offline();
    final left = failNext['upload'] ?? 0;
    if (left > 0) {
      failNext['upload'] = left - 1;
      throw const ApiException(
        code: 'http_503',
        message: 'unavailable',
        statusCode: 503,
      );
    }
    if (expireNextUpload || ticket.expiresAt.isBefore(_clock().toUtc())) {
      expireNextUpload = false;
      throw const UploadTicketExpired();
    }
    if (bytes.length > ticket.maxBytes) {
      throw const ApiException(
        code: 'file_too_large',
        message: 'That photo is too large.',
        statusCode: 413,
      );
    }
    onProgress?.call(bytes.length ~/ 2, bytes.length);
    await blobs.put('raw/${ticket.imageId}', bytes);
    onProgress?.call(bytes.length, bytes.length);
  }

  static String? _sniff(Uint8List b) {
    if (b.length > 3 && b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff) {
      return 'image/jpeg';
    }
    if (b.length > 8 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4e &&
        b[3] == 0x47) {
      return 'image/png';
    }
    if (b.length > 12 &&
        String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    if (b.length > 12 && String.fromCharCodes(b.sublist(4, 8)) == 'ftyp') {
      return 'image/heic';
    }
    return null;
  }

  @override
  Future<Garment> complete(String garmentId, String imageId) async {
    _enter('complete');
    final g = _find(garmentId);
    final image = _image(g, imageId);
    if (image['status'] == 'awaiting_upload') {
      final raw = await blobs.get('raw/$imageId');
      if (raw == null) {
        throw const ApiException(
          code: 'upload_missing',
          message:
              "We haven't received the photo yet. Please retry the upload.",
          statusCode: 409,
        );
      }
      if (_sniff(raw) == null) {
        await blobs.delete('raw/$imageId');
        image['status'] = 'failed';
        image['error'] = 'unsupported_media: not a supported image';
        (g['analysis'] as Map)['status'] = 'needs_manual';
        _save();
        throw const ApiException(
          code: 'unsupported_media',
          message: 'Only JPEG, PNG, WebP and HEIC photos are supported.',
          statusCode: 415,
        );
      }
      image['status'] = 'uploaded';
      (g['analysis'] as Map)['status'] = 'processing';
      _touch(g);
      _save();
      _scheduleProcessing(g);
    }
    return _garment(g);
  }

  void _touch(Json g) => g['updated_at'] = _clock().toUtc().toIso8601String();

  // ---- the "worker": processing then analysis --------------------------------------------------------------

  void _resume(Json g) {
    final status = (g['analysis'] as Map)['status'];
    if (status == 'processing') _scheduleProcessing(g);
    if (status == 'analysing') _scheduleAnalysis(g);
  }

  void _scheduleProcessing(Json g) {
    final id = 'p${g['id']}';
    if (!_scheduled.add(id)) return;
    Future<void>.delayed(processingDelay, () async {
      _scheduled.remove(id);
      final image = (g['images'] as List)
          .cast<Json>()
          .where((i) => i['status'] == 'uploaded')
          .firstOrNull;
      if (image == null) return;
      final raw = await blobs.get('raw/${image['id']}');
      if (raw == null) return;
      final decoded = img.decodeImage(raw);
      if (decoded == null) {
        image['status'] = 'failed';
        image['error'] = 'image_invalid: Could not read the image';
        (g['analysis'] as Map)['status'] = 'needs_manual';
      } else {
        await blobs.put('blob/${image['id']}', raw);
        await blobs.delete('raw/${image['id']}');
        image
          ..['status'] = 'ready'
          ..['width'] = decoded.width
          ..['height'] = decoded.height
          ..['urls'] = {
            for (final s in ['s', 'm', 'l', 'full'])
              s: 'mock://blob/${image['id']}/$s',
          };
        g['cover_image_id'] ??= image['id'];
        (g['analysis'] as Map)['status'] = 'analysing';
      }
      _touch(g);
      _save();
      if ((g['analysis'] as Map)['status'] == 'analysing') _scheduleAnalysis(g);
    });
  }

  void _scheduleAnalysis(Json g, {bool reanalyse = false}) {
    final id = 'a${g['id']}';
    if (!_scheduled.add(id)) return;
    Future<void>.delayed(analysisDelay, () async {
      _scheduled.remove(id);
      final image = (g['images'] as List)
          .cast<Json>()
          .where((i) => i['status'] == 'ready')
          .firstOrNull;
      if (image == null) return;
      final bytes = await blobs.get('blob/${image['id']}') ?? Uint8List(0);
      final analysis = g['analysis'] as Map<String, dynamic>;
      try {
        final fields = vision.analyse(
          image['filename'] as String?,
          bytes,
          department: department(),
        );
        final previous = reanalyse
            ? (analysis['fields'] as Map?)?.cast<String, dynamic>()
            : null;
        for (final f in Taxonomy.instance.aiFields) {
          final fresh = fields[f]!['value'];
          if (previous == null ||
              '${g[f]}' == '${(previous[f] as Map)['value']}') {
            g[f] = fresh;
          }
        }
        analysis
          ..['fields'] = fields
          ..['status'] = 'done'
          ..['provider'] = 'fake'
          ..['model'] = 'fake-vision'
          ..['version'] = '1'
          ..['low_confidence_fields'] = [
            for (final e in fields.entries)
              if ((e.value['confidence']! as num) < 0.7) e.key,
          ];
        // The fake vision signals a permanent failure with a StateError.
        // ignore: avoid_catching_errors
      } on StateError {
        analysis['status'] = 'needs_manual';
      }
      _touch(g);
      _save();
    });
  }

  // ---- edits -------------------------------------------------------------------------------------------------

  ApiException _invalid(String field, String message) => ApiException(
    code: 'invalid_garment',
    message: 'Some details are not valid.',
    statusCode: 422,
    details: {
      'errors': [
        {'field': field, 'message': message},
      ],
    },
  );

  @override
  Future<Garment> patch(String id, Map<String, Object?> changes) async {
    _enter('patch');
    final g = _find(id);
    final tx = Taxonomy.instance;
    final merged =
        {
          for (final k in [
            'category',
            'subcategory',
            'primary_color',
            'secondary_color',
          ])
            k: g[k],
        }..addAll({
          for (final e in changes.entries) e.key: e.value,
        });
    if (changes.containsKey('category') &&
        !tx.categoryIds.contains(changes['category'])) {
      throw _invalid('category', 'unknown category');
    }
    if (changes.containsKey('subcategory') || changes.containsKey('category')) {
      final sub = merged['subcategory'] as String?;
      if (sub != null && tx.categoryOf(sub) != merged['category']) {
        throw _invalid('subcategory', 'does not belong to the category');
      }
    }
    if (changes['primary_color'] != null &&
        tx.colorById(changes['primary_color']! as String) == null) {
      throw _invalid('primary_color', 'unknown colour');
    }
    final sec = merged['secondary_color'];
    if (sec != null && sec == merged['primary_color']) {
      throw _invalid('secondary_color', 'must differ from primary_color');
    }
    if (changes['formality'] != null &&
        !tx.formality.contains(changes['formality'])) {
      throw _invalid('formality', 'must be 1-5');
    }
    if (changes.containsKey('seasons')) {
      final s = changes['seasons'];
      if (s is! List || s.isEmpty || !s.every(tx.seasons.contains)) {
        throw _invalid('seasons', 'pick at least one season');
      }
    }
    if (changes['unavailable_until'] != null &&
        DateTime.parse(
          changes['unavailable_until']! as String,
        ).isBefore(DateTime(_clock().year, _clock().month, _clock().day))) {
      throw _invalid('unavailable_until', 'must not be in the past');
    }
    if (changes['archived'] == false && g['archived'] == true) _checkRoom(1);

    for (final e in changes.entries) {
      final v = e.value;
      switch (e.key) {
        case 'archived':
          g['archived'] = v == true;
        case 'reviewed':
          g['reviewed'] = v == true;
        case 'availability':
          g['availability'] = v;
          if (v == 'available') g['unavailable_until'] = null;
        default:
          g[e.key] = v;
      }
    }
    g['excluded_from_outfits'] =
        g['archived'] == true || g['availability'] != 'available';
    final analysis = g['analysis'] as Map<String, dynamic>;
    if (analysis['status'] == 'needs_manual' &&
        [
          for (final f in [
            'category',
            'subcategory',
            'primary_color',
            'pattern',
            'formality',
          ])
            g[f],
        ].every((x) => x != null) &&
        ((g['seasons'] as List?)?.isNotEmpty ?? false)) {
      analysis['status'] = 'done';
    }
    _touch(g);
    _save();
    return _garment(g);
  }

  @override
  Future<void> delete(String id) async {
    _enter('delete');
    final g = _find(id);
    for (final i in (g['images'] as List).cast<Json>()) {
      await blobs.delete('blob/${i['id']}');
      await blobs.delete('raw/${i['id']}');
    }
    _all.remove(g);
    _save();
  }

  @override
  Future<Garment> reanalyse(String id) async {
    _enter('reanalyse');
    final g = _find(id);
    final analysis = g['analysis'] as Map<String, dynamic>;
    if (!(g['images'] as List).cast<Json>().any(
      (i) => i['status'] == 'ready',
    )) {
      throw const ApiException(
        code: 'image_not_ready',
        message: 'There is no processed photo to analyse yet.',
        statusCode: 409,
      );
    }
    if (analysis['status'] == 'processing' ||
        analysis['status'] == 'analysing') {
      throw const ApiException(
        code: 'analysis_in_progress',
        message: 'Analysis is already running.',
        statusCode: 409,
      );
    }
    analysis['status'] = 'analysing';
    _touch(g);
    _save();
    _scheduleAnalysis(g, reanalyse: true);
    return _garment(g);
  }

  @override
  Future<List<Garment>> seedSample() async {
    _enter('seedSample');
    if (!_all.any((g) => g['is_sample'] == true)) {
      final now = _clock().toUtc().toIso8601String();
      for (final s in sampleGarments) {
        _all.add({
          'id': const Uuid().v4(),
          'client_id': 'sample-${s.asset}',
          'category': s.category,
          'subcategory': s.subcategory,
          'primary_color': s.primaryColor,
          'secondary_color': null,
          'pattern': 'solid',
          'formality': s.formality,
          'seasons': s.seasons,
          'fit': null,
          'material': null,
          'brand': null,
          'notes': null,
          'favorite': false,
          'availability': 'available',
          'unavailable_until': null,
          'archived': false,
          'reviewed': true,
          'excluded_from_outfits': false,
          'is_sample': true,
          'sample_asset': s.asset,
          'analysis': {
            'status': 'done',
            'fields': null,
            'low_confidence_fields': <String>[],
            'provider': null,
            'model': null,
            'version': null,
            'taxonomy_version': 1,
          },
          'images': <Json>[],
          'cover_image_id': null,
          'created_at': now,
          'updated_at': now,
        });
      }
      _save();
    }
    return [
      for (final g in _all.where((g) => g['is_sample'] == true)) _garment(g),
    ];
  }

  /// Deletes the mock account's closet and pictures (sign-out on this device).
  Future<void> wipe() async {
    _cache = [];
    _scheduled.clear();
    await store.remove(_key);
    await blobs.clear();
  }

  /// The garment exactly as the mock "server" would return it (contract test: same keys as the API).
  @visibleForTesting
  Json rawJson(String id) => Map.of(_find(id));

  /// Bytes behind a `mock://blob/<imageId>/<size>` URL.
  Future<Uint8List?> blobFor(String imageId) => blobs.get('blob/$imageId');

  /// For tests: wait for the simulated worker to finish everything in flight.
  Future<void> settle() async {
    for (var i = 0; i < 50; i++) {
      final busy = _all.any(
        (g) => const [
          'processing',
          'analysing',
        ].contains((g['analysis'] as Map)['status']),
      );
      if (!busy && _scheduled.isEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }
}
