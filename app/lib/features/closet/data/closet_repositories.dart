import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:stylist/core/network/api_client.dart';
import 'package:stylist/core/storage/key_value_store.dart';
import 'package:stylist/features/closet/domain/closet_item.dart';

/// Phase 1 stub. Phase 2 replaces this with the real closet (camera capture,
/// upload, AI tagging) behind the same interface.
abstract class ClosetRepository {
  Future<List<ClosetItem>> items();
  Future<List<ClosetItem>> sampleItems();

  /// The "use sample closet" shortcut: adds all sample items to the user's closet.
  Future<List<ClosetItem>> addSampleCloset();
  Future<void> clear();
}

typedef SampleLoader = Future<List<ClosetItem>> Function();

class StubClosetRepository implements ClosetRepository {
  StubClosetRepository(this._store, this._loadSample);
  final KeyValueStore _store;
  final SampleLoader _loadSample;
  static const _key = 'closet_items_v1';

  @override
  Future<List<ClosetItem>> items() async {
    final raw = _store.read(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => ClosetItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<List<ClosetItem>> sampleItems() => _loadSample();

  @override
  Future<List<ClosetItem>> addSampleCloset() async {
    final sample = await _loadSample();
    await _store.write(
      _key,
      jsonEncode(sample.map((e) => e.toJson()).toList()),
    );
    return sample;
  }

  @override
  Future<void> clear() => _store.remove(_key);
}

Future<List<ClosetItem>> loadSampleFromApi(Dio dio) async {
  final res = await guarded(() => dio.get<List<dynamic>>('/v1/sample/closet'));
  return res.data!
      .map((e) => ClosetItem.fromJson((e as Map).cast<String, dynamic>()))
      .toList();
}
