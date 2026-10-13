import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:stylist/core/network/api_client.dart';
import 'package:stylist/core/storage/key_value_store.dart';
import 'package:stylist/features/auth/domain/auth_provider.dart';
import 'package:stylist/features/consent/domain/consent.dart';

class HttpConsentRepository implements ConsentRepository {
  HttpConsentRepository(this._dio);
  final Dio _dio;

  @override
  Future<ConsentState> get() async {
    final res = await guarded(
      () => _dio.get<Map<String, dynamic>>('/v1/me/consents'),
    );
    return ConsentState.fromJson(res.data!);
  }

  @override
  Future<ConsentState> put({
    bool? analyticsOptIn,
    bool? noAiTraining,
    bool? locationExplained,
  }) async {
    final res = await guarded(
      () => _dio.put<Map<String, dynamic>>(
        '/v1/me/consents',
        data: {
          'analytics_opt_in': ?analyticsOptIn,
          'no_ai_training': ?noAiTraining,
          'location_explained': ?locationExplained,
        },
      ),
    );
    return ConsentState.fromJson(res.data!);
  }
}

class MockConsentRepository implements ConsentRepository {
  MockConsentRepository(this._auth, this._store);
  final AuthProvider _auth;
  final KeyValueStore _store;
  final List<Map<String, dynamic>> puts = [];

  String get _key => 'mock_server_consents_${_auth.currentUser?.uid}';

  @override
  Future<ConsentState> get() async {
    final raw = _store.read(_key);
    return raw == null
        ? const ConsentState()
        : ConsentState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<ConsentState> put({
    bool? analyticsOptIn,
    bool? noAiTraining,
    bool? locationExplained,
  }) async {
    puts.add({
      'analytics_opt_in': analyticsOptIn,
      'no_ai_training': noAiTraining,
      'location_explained': locationExplained,
    });
    final next = (await get()).copyWith(
      analyticsOptIn: analyticsOptIn,
      noAiTraining: noAiTraining,
      locationExplained: locationExplained,
    );
    await _store.write(_key, jsonEncode(next.toJson()));
    return next;
  }
}
