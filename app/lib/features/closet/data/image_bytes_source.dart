import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:stylist/features/closet/data/blob_store.dart';
import 'package:stylist/features/closet/data/mock_closet.dart';

/// Fetches garment pictures and remembers them on disk.
///
/// Signed URLs change every time the API hands one out, so the cache key is the image id + size, never
/// the URL: scrolling a 500-item closet re-uses what is already on the device.
abstract class ImageBytesSource {
  Future<Uint8List?> load({
    required String imageId,
    required String variant,
    required String? url,
  });
}

class HttpImageBytesSource implements ImageBytesSource {
  HttpImageBytesSource(this._cache, [Dio? dio])
    : _dio = dio ?? Dio(BaseOptions(responseType: ResponseType.bytes));
  final BlobStore _cache;
  final Dio _dio;
  final Map<String, Future<Uint8List?>> _inFlight = {};

  @override
  Future<Uint8List?> load({
    required String imageId,
    required String variant,
    required String? url,
  }) {
    final key = '${imageId}_$variant';
    return _inFlight[key] ??= _fetch(key, url).whenComplete(
      () => _inFlight.remove(key),
    );
  }

  Future<Uint8List?> _fetch(String key, String? url) async {
    final hit = await _cache.get(key);
    if (hit != null) return hit;
    if (url == null) return null;
    try {
      final res = await _dio.get<List<int>>(url);
      final data = res.data;
      if (data == null) return null;
      final bytes = Uint8List.fromList(data);
      await _cache.put(key, bytes);
      return bytes;
    } on DioException {
      return null; // the grid shows a placeholder; a later scroll retries
    }
  }
}

class MockImageBytesSource implements ImageBytesSource {
  MockImageBytesSource(this._backend);
  final MockClosetBackend _backend;

  @override
  Future<Uint8List?> load({
    required String imageId,
    required String variant,
    required String? url,
  }) => _backend.blobFor(imageId);
}
