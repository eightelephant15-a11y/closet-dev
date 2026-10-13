import 'dart:async';

import 'package:stylist/core/storage/key_value_store.dart';
import 'package:stylist/features/auth/domain/auth_provider.dart';
import 'package:uuid/uuid.dart';

/// Auth for mock mode and tests. Mimics Firebase semantics: linking keeps the
/// uid; linking to a Google account that already exists throws
/// [CredentialAlreadyInUse].
class FakeAuthProvider implements AuthProvider {
  FakeAuthProvider({
    KeyValueStore? store,
    this.googleEmail = 'ada@example.com',
    this.googleName = 'Ada Lovelace',
    this.googleUid = 'google-ada',
    this.googleAccountExists = false,
    this.cancelNextGoogle = false,
  }) : _store = store {
    final saved = _store?.read(_key);
    if (saved != null) {
      final parts = saved.split('|');
      _user = AuthUser(
        uid: parts[0],
        isAnonymous: parts[1] == 'anon',
        email: parts[2].isEmpty ? null : parts[2],
        displayName: parts[3].isEmpty ? null : parts[3],
      );
    }
  }

  static const _key = 'fake_auth_user';
  final KeyValueStore? _store;
  final String googleEmail;
  final String googleName;
  final String googleUid;

  /// When true, the Google identity is already attached to a different uid.
  bool googleAccountExists;
  bool cancelNextGoogle;

  AuthUser? _user;
  final _controller = StreamController<AuthUser?>.broadcast();
  int tokenRefreshes = 0;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  Future<void> _set(AuthUser? u) async {
    _user = u;
    if (u == null) {
      await _store?.remove(_key);
    } else {
      await _store?.write(
        _key,
        '${u.uid}|${u.isAnonymous ? 'anon' : 'full'}|${u.email ?? ''}|${u.displayName ?? ''}',
      );
    }
    _controller.add(u);
  }

  AuthUser get _googleUser => AuthUser(
    uid: googleUid,
    isAnonymous: false,
    email: googleEmail,
    displayName: googleName,
  );

  void _checkCancel() {
    if (cancelNextGoogle) {
      cancelNextGoogle = false;
      throw const AuthCancelled();
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    _checkCancel();
    await _set(_googleUser);
    return _googleUser;
  }

  @override
  Future<AuthUser> signInAnonymously() async {
    final u = AuthUser(uid: 'anon-${const Uuid().v4()}', isAnonymous: true);
    await _set(u);
    return u;
  }

  @override
  Future<AuthUser> linkWithGoogle() async {
    final current = _user;
    if (current == null || !current.isAnonymous) {
      throw StateError('No anonymous user to link');
    }
    _checkCancel();
    if (googleAccountExists) {
      throw CredentialAlreadyInUse(signInWithGoogle);
    }
    final linked = AuthUser(
      uid: current.uid,
      isAnonymous: false,
      email: googleEmail,
      displayName: googleName,
    );
    await _set(linked);
    return linked;
  }

  @override
  Future<String?> idToken({bool forceRefresh = false}) async {
    final u = _user;
    if (u == null) return null;
    if (forceRefresh) tokenRefreshes++;
    return 'fake:${u.uid}:${u.email ?? ''}${u.displayName == null ? '' : ':${u.displayName}'}';
  }

  @override
  Future<void> signOut() => _set(null);
}
