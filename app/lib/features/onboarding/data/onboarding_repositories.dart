import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:stylist/core/network/api_client.dart';
import 'package:stylist/core/network/api_exception.dart';
import 'package:stylist/core/storage/key_value_store.dart';
import 'package:stylist/features/auth/domain/auth_provider.dart';
import 'package:stylist/features/config/domain/remote_config.dart';
import 'package:stylist/features/onboarding/domain/onboarding_repository.dart';

class HttpOnboardingRepository implements OnboardingRepository {
  HttpOnboardingRepository(this._dio);
  final Dio _dio;

  @override
  Future<RemoteOnboarding> getState() async {
    final res = await guarded(
      () => _dio.get<Map<String, dynamic>>('/v1/onboarding'),
    );
    return RemoteOnboarding.fromJson(res.data!);
  }

  @override
  Future<void> putState(Map<String, dynamic> payload) =>
      guarded(() => _dio.put<void>('/v1/onboarding', data: payload));

  @override
  Future<void> confirmAge() => guarded(
    () => _dio.post<void>(
      '/v1/me/age-confirmation',
      data: {'confirmed_16_plus': true},
    ),
  );

  @override
  Future<void> rejectAge() => guarded(
    () => _dio.post<void>(
      '/v1/me/age-confirmation',
      data: {'confirmed_16_plus': false},
    ),
  );

  @override
  Future<Map<String, dynamic>> getPreferenceAnswers() async {
    final res = await guarded(
      () => _dio.get<Map<String, dynamic>>('/v1/me/preferences'),
    );
    return (res.data!['answers'] as Map).cast<String, dynamic>();
  }

  @override
  Future<void> putPreferences(Map<String, dynamic> answers) => guarded(
    () => _dio.put<void>('/v1/me/preferences', data: {'answers': answers}),
  );
}

/// Fake server for mock mode: persists to the local store, honours the same
/// merge rules as the API (completed steps only grow, first TTFO wins).
class MockOnboardingRepository implements OnboardingRepository {
  MockOnboardingRepository(this._auth, this._store, this._variant);

  final AuthProvider _auth;
  final KeyValueStore _store;
  final OnboardingVariant Function() _variant;
  bool offline = false;
  int putCalls = 0;
  final List<Map<String, dynamic>> puts = [];

  String get _key => 'mock_server_onboarding_${_auth.currentUser?.uid}';
  String get _prefsKey => 'mock_server_prefs_${_auth.currentUser?.uid}';

  void _guard() {
    if (offline) throw const ApiException.offline();
    if (_auth.currentUser == null) {
      throw const ApiException(
        code: 'missing_token',
        message: 'Auth required',
        statusCode: 401,
      );
    }
  }

  Map<String, dynamic> _row() {
    final raw = _store.read(_key);
    if (raw != null) return (jsonDecode(raw) as Map).cast<String, dynamic>();
    return {
      'variant': _variant() == OnboardingVariant.closetFirst
          ? 'closet_first'
          : 'quiz_first',
      'current_step': 'welcome',
      'completed_steps': <String>[],
      'completed_at': null,
      'time_to_first_outfit_ms': null,
    };
  }

  @override
  Future<RemoteOnboarding> getState() async {
    _guard();
    final row = _row();
    await _store.write(_key, jsonEncode(row));
    return RemoteOnboarding.fromJson(row);
  }

  @override
  Future<void> putState(Map<String, dynamic> payload) async {
    _guard();
    putCalls++;
    puts.add(payload);
    final row = _row();
    if (payload['current_step'] != null) {
      row['current_step'] = payload['current_step'];
    }
    if (payload['completed_steps'] != null) {
      row['completed_steps'] = {
        ...(row['completed_steps'] as List),
        ...(payload['completed_steps'] as List),
      }.toList()..sort();
    }
    if (payload['time_to_first_outfit_ms'] != null &&
        row['time_to_first_outfit_ms'] == null) {
      row['time_to_first_outfit_ms'] = payload['time_to_first_outfit_ms'];
    }
    if (payload['completed'] == true && row['completed_at'] == null) {
      row['completed_at'] = DateTime.now().toUtc().toIso8601String();
      row['current_step'] = 'done';
    }
    await _store.write(_key, jsonEncode(row));
  }

  bool ageConfirmed = false;
  bool ageRejected = false;

  @override
  Future<void> confirmAge() async {
    _guard();
    ageConfirmed = true;
  }

  @override
  Future<void> rejectAge() async {
    _guard();
    ageRejected = true;
    await _store.remove(_key);
    await _store.remove(_prefsKey);
    throw const ApiException(
      code: 'age_under_minimum',
      message: 'You must be 16 or older',
      statusCode: 403,
    );
  }

  @override
  Future<Map<String, dynamic>> getPreferenceAnswers() async {
    _guard();
    final raw = _store.read(_prefsKey);
    return raw == null ? {} : (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  @override
  Future<void> putPreferences(Map<String, dynamic> answers) async {
    _guard();
    final merged = {...await getPreferenceAnswers(), ...answers};
    await _store.write(_prefsKey, jsonEncode(merged));
  }
}
