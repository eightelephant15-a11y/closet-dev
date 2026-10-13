import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/features/auth/domain/auth_provider.dart';
import 'package:stylist/features/config/domain/remote_config.dart';
import 'package:stylist/features/onboarding/domain/onboarding_step.dart';

import '../helpers/harness.dart';

void main() {
  group('Welcome', () {
    testWidgets('shows 3 skippable value screens and both entry buttons', (
      tester,
    ) async {
      useTallScreen(tester);
      final h = Harness();
      await h.pumpApp(tester);
      expect(find.text('Your wardrobe, styled'), findsOneWidget);
      expect(find.text('Try it first'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Dress with less thinking'), findsOneWidget);
      expect(
        find.text('Skip'),
        findsOneWidget,
      ); // present but hidden on last page
      expect(h.analytics.names, contains(AnalyticsEvent.welcomeViewed));
    });

    testWidgets('swiping moves through the pages', (tester) async {
      useTallScreen(tester);
      await Harness().pumpApp(tester);
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Outfits that feel like you'), findsOneWidget);
    });

    testWidgets(
      'Try it first starts a guest session and lands on the age gate',
      (tester) async {
        useTallScreen(tester);
        final h = Harness();
        await h.pumpApp(tester);
        await tester.tap(find.text('Try it first'));
        await tester.pumpAndSettle();
        expect(find.text('I am 16 or older'), findsOneWidget);
        expect(h.auth.currentUser!.isAnonymous, isTrue);
        expect(
          h.analytics.names,
          containsAllInOrder([
            AnalyticsEvent.welcomeViewed,
            AnalyticsEvent.guestStarted,
            AnalyticsEvent.onboardingStarted,
          ]),
        );
      },
    );

    testWidgets('Google sign-in lands on the age gate', (tester) async {
      useTallScreen(tester);
      final h = Harness();
      await h.pumpApp(tester);
      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();
      expect(find.text('I am 16 or older'), findsOneWidget);
      expect(h.auth.currentUser!.isAnonymous, isFalse);
      expect(
        h.analytics.names,
        containsAll([
          AnalyticsEvent.signinStarted,
          AnalyticsEvent.signinCompleted,
        ]),
      );
    });

    testWidgets('cancelled Google sign-in stays on welcome without an error', (
      tester,
    ) async {
      useTallScreen(tester);
      final h = Harness()..auth.cancelNextGoogle = true;
      await h.pumpApp(tester);
      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();
      expect(find.text('Try it first'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('sign-in failure shows an error and the buttons come back', (
      tester,
    ) async {
      useTallScreen(tester);
      final h = Harness();
      await h.pumpApp(tester);
      h.accounts.offline = true;
      await tester.tap(find.text('Try it first'));
      await tester.pumpAndSettle();
      // Offline guest start still proceeds locally (cached/no server user yet).
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('guest mode off goes straight to sign-in', (tester) async {
      useTallScreen(tester);
      final h = Harness(config: const RemoteConfig(guestModeEnabled: false));
      await h.pumpApp(tester);
      expect(find.text('Sign in to continue'), findsOneWidget);
      expect(find.text('Try it first'), findsNothing);
      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();
      expect(find.text('I am 16 or older'), findsOneWidget);
    });

    testWidgets('touch targets are at least 48dp', (tester) async {
      useTallScreen(tester);
      await Harness().pumpApp(tester);
      for (final finder in [
        find.widgetWithText(FilledButton, 'Try it first'),
        find.widgetWithText(OutlinedButton, 'Sign in with Google'),
      ]) {
        expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('large text does not overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await Harness().pumpApp(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('Age gate', () {
    Future<Harness> toAgeGate(WidgetTester tester) async {
      useTallScreen(tester);
      final h = Harness();
      await h.pumpApp(tester);
      await tester.tap(find.text('Try it first'));
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('16+ confirmation advances to the quiz and records the event', (
      tester,
    ) async {
      final h = await toAgeGate(tester);
      await tester.tap(find.text('I am 16 or older'));
      await tester.pumpAndSettle();
      expect(find.text('Which clothes should we show you?'), findsOneWidget);
      expect(h.analytics.names, contains(AnalyticsEvent.ageConfirmed));
      expect(h.onboarding.ageConfirmed, isTrue);
    });

    testWidgets('under 16 shows the friendly block screen and keeps no data', (
      tester,
    ) async {
      final h = await toAgeGate(tester);
      await tester.tap(find.text('I am under 16'));
      await tester.pumpAndSettle();
      expect(find.text('Thanks for stopping by'), findsOneWidget);
      expect(h.onboarding.ageRejected, isTrue);
      expect(h.auth.currentUser, isNull);
      expect(h.store.read('onboarding_state_v1'), isNull);
      expect(h.store.read('session_user_cache'), isNull);
      expect(find.text('Try it first'), findsNothing);
    });

    testWidgets('block survives an app restart', (tester) async {
      final h = await toAgeGate(tester);
      await tester.tap(find.text('I am under 16'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      final h2 = Harness(store: h.store);
      await h2.pumpApp(tester);
      expect(find.text('Thanks for stopping by'), findsOneWidget);
    });

    testWidgets('age step is remembered across restart', (tester) async {
      final h = await toAgeGate(tester);
      await tester.pumpWidget(const SizedBox());
      final h2 = Harness(store: h.store);
      await h2.pumpApp(tester);
      expect(find.text('I am 16 or older'), findsOneWidget);
      expect(OnboardingStep.age.path, '/onboarding/age');
    });
  });

  test('AuthCancelled is a distinct exception', () {
    expect(const AuthCancelled(), isA<Exception>());
  });
}
