import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/core/network/api_exception.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/auth/domain/account_repository.dart';
import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/auth/domain/auth_provider.dart';

enum SessionStatus { unknown, signedOut, guest, member, pendingDeletion }

class SessionState {
  const SessionState({
    this.status = SessionStatus.unknown,
    this.user,
    this.offline = false,
  });

  final SessionStatus status;
  final AppUser? user;

  /// True when the server could not be reached and [user] comes from cache.
  final bool offline;

  bool get isSignedIn =>
      status == SessionStatus.guest || status == SessionStatus.member;
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(
      SessionController.new,
    );

class SessionController extends Notifier<SessionState> {
  static const _cacheKey = 'session_user_cache';

  AuthProvider get _auth => ref.read(authProviderProvider);
  AccountRepository get _accounts => ref.read(accountRepositoryProvider);

  @override
  SessionState build() => const SessionState();

  /// Called once at app start.
  Future<void> init() async {
    final u = _auth.currentUser;
    if (u == null) {
      state = const SessionState(status: SessionStatus.signedOut);
      return;
    }
    await _sync(u);
  }

  Future<void> continueAsGuest() async {
    final config = await ref.read(remoteConfigProvider.future);
    if (!config.guestModeEnabled) {
      throw const ApiException(
        code: 'guest_disabled',
        message: 'Guest mode is disabled',
      );
    }
    await _sync(await _auth.signInAnonymously());
  }

  Future<void> signInWithGoogle() async =>
      _sync(await _auth.signInWithGoogle());

  /// Upgrades the current guest to a Google account without losing data.
  Future<void> upgradeGuest() async {
    final current = _auth.currentUser;
    if (current == null || !current.isAnonymous) return;
    AppUser user;
    try {
      await _auth.linkWithGoogle();
      user = await _accounts.upgrade();
    } on CredentialAlreadyInUse catch (e) {
      // Google account already exists: sign in to it and merge the guest's data.
      final guestToken = await _auth.idToken();
      await e.signInToExisting();
      await _accounts.createSession();
      user = await _accounts.upgrade(mergeFromGuestToken: guestToken);
    }
    await _remember(user);
    state = SessionState(status: SessionStatus.member, user: user);
  }

  Future<void> signOut() async {
    try {
      await _accounts.signOut();
    } on ApiException {
      // Best effort: local sign-out must always succeed.
    }
    await _auth.signOut();
    await ref.read(keyValueStoreProvider).remove(_cacheKey);
    ref.read(analyticsServiceProvider).reset();
    state = const SessionState(status: SessionStatus.signedOut);
  }

  /// Server revoked this device's session.
  Future<void> onRevoked() async {
    await _auth.signOut();
    state = const SessionState(status: SessionStatus.signedOut);
  }

  /// Cancels a pending deletion and carries on.
  Future<void> restoreAccount() async {
    final user = await _accounts.restore();
    await _remember(user);
    final anon = _auth.currentUser?.isAnonymous ?? false;
    state = SessionState(
      status: anon ? SessionStatus.guest : SessionStatus.member,
      user: user,
    );
  }

  void updateUser(AppUser user) {
    state = SessionState(
      status: state.status,
      user: user,
      offline: state.offline,
    );
    unawaited(_remember(user));
  }

  Future<void> _sync(AuthUser u) async {
    var status = u.isAnonymous ? SessionStatus.guest : SessionStatus.member;
    try {
      final user = await _accounts.createSession();
      if (user.status == UserStatus.pendingDeletion) {
        status = SessionStatus.pendingDeletion;
      }
      await _remember(user);
      // Internal id only: never email or name.
      ref.read(analyticsServiceProvider).identify(user.id);
      state = SessionState(status: status, user: user);
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;
      state = SessionState(status: status, user: _cached(), offline: true);
    }
  }

  Future<void> _remember(AppUser user) => ref
      .read(keyValueStoreProvider)
      .write(_cacheKey, jsonEncode(user.toJson()));

  AppUser? _cached() {
    final raw = ref.read(keyValueStoreProvider).read(_cacheKey);
    return raw == null
        ? null
        : AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
