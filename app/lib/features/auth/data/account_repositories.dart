import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:stylist/core/network/api_client.dart';
import 'package:stylist/core/network/api_exception.dart';
import 'package:stylist/core/storage/key_value_store.dart';
import 'package:stylist/features/auth/domain/account_repository.dart';
import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/auth/domain/auth_provider.dart';
import 'package:uuid/uuid.dart';

class HttpAccountRepository implements AccountRepository {
  HttpAccountRepository(
    this._dio, {
    required this.deviceId,
    required this.platform,
  });
  final Dio _dio;
  final String deviceId;
  final String platform;

  @override
  Future<AppUser> createSession() async {
    final res = await guarded(
      () => _dio.post<Map<String, dynamic>>(
        '/v1/auth/session',
        data: {
          'device_id': deviceId,
          'platform': platform,
          'app_version': '1.0.0',
        },
      ),
    );
    return AppUser.fromJson(res.data!['user'] as Map<String, dynamic>);
  }

  @override
  Future<AppUser> upgrade({String? mergeFromGuestToken}) async {
    final res = await guarded(
      () => _dio.post<Map<String, dynamic>>(
        '/v1/auth/upgrade',
        data: {'merge_from_token': ?mergeFromGuestToken},
      ),
    );
    return AppUser.fromJson(res.data!);
  }

  @override
  Future<AppUser> me() async {
    final res = await guarded(() => _dio.get<Map<String, dynamic>>('/v1/me'));
    return AppUser.fromJson(res.data!);
  }

  @override
  Future<AppUser> patchMe(UserPatch patch) async {
    final res = await guarded(
      () => _dio.patch<Map<String, dynamic>>('/v1/me', data: patch.toJson()),
    );
    return AppUser.fromJson(res.data!);
  }

  @override
  Future<void> signOut() => guarded(() => _dio.post<void>('/v1/auth/sign-out'));
}

/// In-memory + locally persisted fake of the server's account behaviour,
/// including guest -> account upgrade and merge semantics.
class MockAccountRepository implements AccountRepository {
  MockAccountRepository(this._auth, this._store);
  final AuthProvider _auth;
  final KeyValueStore _store;
  static const _key = 'mock_server_users';

  /// Simulate an unreachable server (offline tests).
  bool offline = false;

  Map<String, Map<String, dynamic>> _load() {
    final raw = _store.read(_key);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as Map).cast<String, dynamic>()),
    );
  }

  Future<void> _save(Map<String, Map<String, dynamic>> users) =>
      _store.write(_key, jsonEncode(users));

  void _guardOnline() {
    if (offline) throw const ApiException.offline();
  }

  AuthUser get _authUser {
    final u = _auth.currentUser;
    if (u == null) {
      throw const ApiException(code: 'missing_token', message: 'Auth required');
    }
    return u;
  }

  @override
  Future<AppUser> createSession() async {
    _guardOnline();
    final u = _authUser;
    final users = _load();
    final row = users.putIfAbsent(
      u.uid,
      () => {
        'id': const Uuid().v4(),
        'is_anonymous': u.isAnonymous,
        'locale': 'en-US',
        'units': 'imperial',
        'email': u.email,
        'display_name': u.displayName,
      },
    );
    await _save(users);
    return AppUser.fromJson(row);
  }

  @override
  Future<AppUser> upgrade({String? mergeFromGuestToken}) async {
    _guardOnline();
    final u = _authUser;
    if (u.isAnonymous) {
      throw const ApiException(
        code: 'not_upgraded',
        message: 'Still anonymous',
      );
    }
    final users = _load();
    final row = users[u.uid] ?? (await _createRow(users, u));
    if (mergeFromGuestToken != null) {
      final guestUid = mergeFromGuestToken.split(':')[1];
      final guest = users[guestUid];
      if (guest == null) {
        throw const ApiException(
          code: 'guest_not_found',
          message: 'Guest not found',
        );
      }
      for (final f in const [
        'city',
        'clothing_department',
        'age_confirmed_at',
        'display_name',
      ]) {
        if (row[f] == null && guest[f] != null) row[f] = guest[f];
      }
      users.remove(guestUid);
    }
    row
      ..['is_anonymous'] = false
      ..['email'] = u.email ?? row['email']
      ..['display_name'] = row['display_name'] ?? u.displayName;
    users[u.uid] = row;
    await _save(users);
    return AppUser.fromJson(row);
  }

  Future<Map<String, dynamic>> _createRow(
    Map<String, Map<String, dynamic>> users,
    AuthUser u,
  ) async => {
    'id': const Uuid().v4(),
    'is_anonymous': false,
    'locale': 'en-US',
    'units': 'imperial',
    'email': u.email,
    'display_name': u.displayName,
  };

  @override
  Future<AppUser> me() async {
    _guardOnline();
    final row = _load()[_authUser.uid];
    if (row == null) {
      throw const ApiException(code: 'no_session', message: 'No session');
    }
    return AppUser.fromJson(row);
  }

  @override
  Future<AppUser> patchMe(UserPatch patch) async {
    _guardOnline();
    final users = _load();
    final row = users[_authUser.uid];
    if (row == null) {
      throw const ApiException(code: 'no_session', message: 'No session');
    }
    row.addAll(patch.toJson());
    await _save(users);
    return AppUser.fromJson(row);
  }

  @override
  Future<void> signOut() async {}
}
