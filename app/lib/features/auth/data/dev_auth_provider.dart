import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:stylist/core/storage/key_value_store.dart';
import 'package:stylist/features/auth/domain/auth_provider.dart';
import 'package:uuid/uuid.dart';

/// Sign-in against the *local* API (`AUTH_MODE=dev`): the server mints signed dev tokens at
/// `POST /dev/token`. Only used by the `dev` flavor with `--dart-define=AUTH_MODE=dev`
/// (see `AppConfig.useDevAuth`). It mimics Firebase's guest -> Google linking by re-minting a token
/// for the same uid with an email attached.
class DevAuthProvider implements AuthProvider {
  DevAuthProvider({
    required this.baseUrl,
    required KeyValueStore store,
    Dio? dio,
    this.googleEmail = 'ada@example.com',
    this.googleName = 'Ada Lovelace',
    this.googleUid = 'dev-google-ada',
  }) : _store = store,
       _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl)) {
    final raw = _store.read(_key);
    if (raw != null) {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _user = _fromJson(j);
      _token = j['token'] as String;
    }
  }

  static const _key = 'dev_auth_user';
  final String baseUrl;
  final KeyValueStore _store;
  final Dio _dio;
  final String googleEmail;
  final String googleName;
  final String googleUid;

  AuthUser? _user;
  String? _token;
  final _controller = StreamController<AuthUser?>.broadcast();

  AuthUser _fromJson(Map<String, dynamic> j) => AuthUser(
    uid: j['uid'] as String,
    isAnonymous: j['is_anonymous'] as bool,
    email: j['email'] as String?,
    displayName: j['name'] as String?,
  );

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  Future<AuthUser> _mint({String? uid, String? email, String? name}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/dev/token',
      data: {'uid': uid, 'email': email, 'name': name},
    );
    final j = res.data!;
    _token = j['token'] as String;
    _user = _fromJson(j);
    await _store.write(_key, jsonEncode({...j, 'token': _token}));
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<AuthUser> signInWithGoogle() =>
      _mint(uid: googleUid, email: googleEmail, name: googleName);

  @override
  Future<AuthUser> signInAnonymously() =>
      _mint(uid: 'dev-guest-${const Uuid().v4()}');

  @override
  Future<AuthUser> linkWithGoogle() {
    final current = _user;
    if (current == null || !current.isAnonymous) {
      throw StateError('No anonymous user to link');
    }
    return _mint(uid: current.uid, email: googleEmail, name: googleName);
  }

  @override
  Future<String?> idToken({bool forceRefresh = false}) async {
    final u = _user;
    if (u == null) return null;
    if (forceRefresh) {
      await _mint(uid: u.uid, email: u.email, name: u.displayName);
    }
    return _token;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _token = null;
    await _store.remove(_key);
    _controller.add(null);
  }
}
