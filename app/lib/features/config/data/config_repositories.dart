import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:stylist/core/network/api_client.dart';
import 'package:stylist/core/network/api_exception.dart';
import 'package:stylist/core/storage/key_value_store.dart';
import 'package:stylist/features/config/domain/remote_config.dart';

class MockConfigRepository implements ConfigRepository {
  MockConfigRepository([this.config = const RemoteConfig()]);
  RemoteConfig config;

  @override
  Future<RemoteConfig> load() async => config;
}

class HttpConfigRepository implements ConfigRepository {
  HttpConfigRepository(this._dio, this._store);
  final Dio _dio;
  final KeyValueStore _store;
  static const _cacheKey = 'remote_config_cache';

  @override
  Future<RemoteConfig> load() async {
    try {
      final res = await guarded(
        () => _dio.get<Map<String, dynamic>>('/v1/config'),
      );
      await _store.write(_cacheKey, jsonEncode(res.data));
      return RemoteConfig.fromApi(res.data!);
    } on ApiException {
      final cached = _store.read(_cacheKey);
      if (cached != null) {
        return RemoteConfig.fromApi(jsonDecode(cached) as Map<String, dynamic>);
      }
      return const RemoteConfig();
    }
  }
}
