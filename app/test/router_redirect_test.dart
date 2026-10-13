import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/features/auth/application/session_controller.dart';
import 'package:stylist/features/config/domain/remote_config.dart';
import 'package:stylist/features/onboarding/domain/onboarding_state.dart';
import 'package:stylist/features/onboarding/domain/onboarding_step.dart';
import 'package:stylist/router/app_router.dart';

String? redirect(
  String location, {
  bool bootDone = true,
  bool blocked = false,
  SessionStatus session = SessionStatus.guest,
  bool guestEnabled = true,
  OnboardingState? onboarding,
}) => decideRedirect(
  location: location,
  bootDone: bootDone,
  blocked: blocked,
  session: session,
  guestEnabled: guestEnabled,
  onboarding: onboarding,
);

OnboardingState state(
  OnboardingStep at, {
  OnboardingVariant v = OnboardingVariant.quizFirst,
}) => OnboardingState.initial(v, DateTime(2026)).copyWith(current: at);

void main() {
  test('before boot everything goes to splash', () {
    expect(redirect('/home', bootDone: false), Routes.splash);
    expect(redirect(Routes.splash, bootDone: false), isNull);
  });

  test('under-16 block wins', () {
    expect(redirect('/home', blocked: true), Routes.blocked);
  });

  test(
    'signed out -> welcome, or straight to sign-in when guest mode is off',
    () {
      expect(
        redirect('/home', session: SessionStatus.signedOut),
        Routes.welcome,
      );
      expect(
        redirect(Routes.welcome, session: SessionStatus.signedOut),
        isNull,
      );
      expect(
        redirect(
          '/home',
          session: SessionStatus.signedOut,
          guestEnabled: false,
        ),
        Routes.signIn,
      );
      expect(
        redirect(
          Routes.welcome,
          session: SessionStatus.signedOut,
          guestEnabled: false,
        ),
        Routes.signIn,
      );
    },
  );

  test('signed in mid-onboarding is forced to the current step', () {
    final s = state(OnboardingStep.quiz);
    expect(redirect(Routes.welcome, onboarding: s), '/onboarding/quiz');
    expect(redirect('/home', onboarding: s), '/onboarding/quiz');
    expect(redirect('/onboarding/quiz', onboarding: s), isNull);
  });

  test('can revisit earlier steps but not skip ahead', () {
    final s = state(OnboardingStep.quiz);
    expect(redirect('/onboarding/age', onboarding: s), isNull);
    expect(redirect('/onboarding/basics', onboarding: s), '/onboarding/quiz');
    expect(redirect('/onboarding/bogus', onboarding: s), '/onboarding/quiz');
  });

  test('deep link /onboarding/resume lands on the saved step', () {
    expect(
      redirect(Routes.resume, onboarding: state(OnboardingStep.permissions)),
      '/onboarding/permissions',
    );
  });

  test('closet_first changes step order', () {
    final s = state(
      OnboardingStep.firstItems,
      v: OnboardingVariant.closetFirst,
    );
    expect(
      redirect('/onboarding/quiz', onboarding: s),
      '/onboarding/first_items',
    );
    expect(redirect('/onboarding/basics', onboarding: s), isNull);
    expect(
      stepsFor(OnboardingVariant.closetFirst).indexOf(OnboardingStep.quiz),
      greaterThan(
        stepsFor(
          OnboardingVariant.closetFirst,
        ).indexOf(OnboardingStep.firstItems),
      ),
    );
  });

  test('completed users leave the flow for home', () {
    final done = state(
      OnboardingStep.done,
    ).copyWith(completedAt: DateTime(2026));
    expect(redirect('/onboarding/quiz', onboarding: done), Routes.home);
    expect(redirect(Routes.welcome, onboarding: done), Routes.home);
    expect(redirect(Routes.home, onboarding: done), isNull);
  });

  test('deep link aliases resume the saved step', () {
    final s = state(OnboardingStep.basics);
    expect(redirect('/resume', onboarding: s), '/onboarding/basics');
  });

  test('pending deletion is routed to restore, settings stay reachable', () {
    expect(
      redirect('/home', session: SessionStatus.pendingDeletion),
      Routes.restore,
    );
    final done = state(
      OnboardingStep.done,
    ).copyWith(completedAt: DateTime(2026));
    expect(redirect('/settings/export', onboarding: done), isNull);
    expect(
      redirect('/settings', onboarding: state(OnboardingStep.quiz)),
      isNull,
    );
  });
}
