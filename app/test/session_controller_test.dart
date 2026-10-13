import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/core/network/api_exception.dart';
import 'package:stylist/features/auth/application/session_controller.dart';
import 'package:stylist/features/auth/data/fake_auth_provider.dart';
import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/auth/domain/auth_provider.dart';
import 'package:stylist/features/config/domain/remote_config.dart';

import 'helpers/harness.dart';

void main() {
  late Harness h;
  late ProviderContainer c;
  SessionController ctl() => c.read(sessionControllerProvider.notifier);
  SessionState state() => c.read(sessionControllerProvider);

  setUp(() {
    h = Harness();
    c = h.container();
  });
  tearDown(() => c.dispose());

  test('init with no user -> signedOut', () async {
    await ctl().init();
    expect(state().status, SessionStatus.signedOut);
  });

  test('guest start creates anonymous user', () async {
    await ctl().continueAsGuest();
    expect(state().status, SessionStatus.guest);
    expect(state().user!.isAnonymous, isTrue);
  });

  test('guest disabled by flag blocks guest start', () async {
    h = Harness(config: const RemoteConfig(guestModeEnabled: false));
    c = h.container();
    expect(ctl().continueAsGuest(), throwsA(isA<ApiException>()));
  });

  test('google sign-in creates member', () async {
    await ctl().signInWithGoogle();
    expect(state().status, SessionStatus.member);
    expect(state().user!.email, 'ada@example.com');
  });

  test('upgrade keeps the same internal user id and data', () async {
    await ctl().continueAsGuest();
    final guestId = state().user!.id;
    await h.accounts.patchMe(
      const UserPatch(
        city: 'Austin',
        clothingDepartment: ClothingDepartment.womenswear,
      ),
    );
    await ctl().upgradeGuest();
    final u = state().user!;
    expect(state().status, SessionStatus.member);
    expect(u.id, guestId);
    expect(u.isAnonymous, isFalse);
    expect(u.email, 'ada@example.com');
    expect(u.city, 'Austin');
    expect(u.clothingDepartment, ClothingDepartment.womenswear);
  });

  test('upgrade into an existing google account merges guest data', () async {
    // Existing member account with its own id.
    final existing = Harness(store: h.store, auth: h.auth);
    await existing.auth.signInWithGoogle();
    final memberId = (await existing.accounts.createSession()).id;
    await existing.auth.signOut();

    await ctl().continueAsGuest();
    await h.accounts.patchMe(const UserPatch(city: 'Austin'));
    h.auth.googleAccountExists = true;

    await ctl().upgradeGuest();
    final u = state().user!;
    expect(u.id, memberId);
    expect(u.city, 'Austin');
    expect(u.isAnonymous, isFalse);
  });

  test('cancelled google link leaves the guest intact', () async {
    await ctl().continueAsGuest();
    final id = state().user!.id;
    h.auth.cancelNextGoogle = true;
    await expectLater(ctl().upgradeGuest(), throwsA(isA<AuthCancelled>()));
    expect(state().status, SessionStatus.guest);
    expect(state().user!.id, id);
    await ctl().upgradeGuest(); // retry succeeds
    expect(state().user!.id, id);
  });

  test('sign out clears state and auth', () async {
    await ctl().signInWithGoogle();
    await ctl().signOut();
    expect(state().status, SessionStatus.signedOut);
    expect(h.auth.currentUser, isNull);
  });

  test('restart resumes the same guest from local storage', () async {
    await ctl().continueAsGuest();
    final id = state().user!.id;
    final h2 = Harness(store: h.store); // new auth/provider objects, same disk
    final c2 = h2.container();
    addTearDown(c2.dispose);
    await c2.read(sessionControllerProvider.notifier).init();
    expect(c2.read(sessionControllerProvider).user!.id, id);
  });

  test('offline start falls back to cached user', () async {
    await ctl().continueAsGuest();
    final id = state().user!.id;
    final h2 = Harness(store: h.store)..accounts.offline = true;
    final c2 = h2.container();
    addTearDown(c2.dispose);
    await c2.read(sessionControllerProvider.notifier).init();
    final s = c2.read(sessionControllerProvider);
    expect(s.offline, isTrue);
    expect(s.status, SessionStatus.guest);
    expect(s.user!.id, id);
  });

  test('fake auth: tokens refresh on demand', () async {
    final auth = FakeAuthProvider();
    await auth.signInAnonymously();
    await auth.idToken(forceRefresh: true);
    expect(auth.tokenRefreshes, 1);
  });
}
