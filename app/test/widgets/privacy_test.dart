import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/features/consent/application/consent_controller.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';
import 'package:stylist/features/onboarding/domain/onboarding_step.dart';

import '../flows/steps.dart';
import '../helpers/harness.dart';

Future<Harness> signedInHome(
  WidgetTester tester, {
  bool guest = false,
  Harness? h,
}) async {
  useTallScreen(tester);
  final harness = h ?? Harness();
  await harness.seedFinishedOnboarding(guest: guest);
  await harness.pumpApp(tester);
  expect(find.text('Finish setting up'), findsOneWidget);
  return harness;
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
}

void main() {
  group('Analytics consent', () {
    testWidgets(
      'nothing is sent before opt-in; opting in flushes the funnel so far',
      (tester) async {
        useTallScreen(tester);
        final h = Harness(analyticsConsent: null);
        await h.pumpApp(tester);
        await tapText(tester, 'Try it first');
        expect(h.analytics.events, isEmpty, reason: 'buffered, not sent');
        await tester.tap(find.text('I am 16 or older'));
        await tester.pumpAndSettle();
        expect(find.text('Help us improve'), findsOneWidget);
        expect(h.analytics.events, isEmpty);
        await tapButton(tester, 'Allow analytics');
        expect(
          h.analytics.names,
          containsAll([
            AnalyticsEvent.welcomeViewed,
            AnalyticsEvent.guestStarted,
            AnalyticsEvent.ageConfirmed,
          ]),
        );
        expect(find.text('Which clothes should we show you?'), findsOneWidget);
        expect(
          containerOf(tester).read(consentControllerProvider).analyticsOptIn,
          isTrue,
        );
        // The decision reached the server with the policy flow.
        await tester.pumpAndSettle();
        expect(h.consents.puts.last['analytics_opt_in'], isTrue);
      },
    );

    testWidgets('declining discards buffered events and sends nothing, ever', (
      tester,
    ) async {
      useTallScreen(tester);
      final h = Harness(analyticsConsent: null);
      await h.pumpApp(tester);
      await tapText(tester, 'Try it first');
      await tester.tap(find.text('I am 16 or older'));
      await tester.pumpAndSettle();
      await tapText(tester, 'No thanks');
      await answerQuizWomenswear(tester);
      expect(h.analytics.events, isEmpty);
      expect(
        containerOf(tester).read(consentControllerProvider).analyticsOptIn,
        isFalse,
      );
      expect(onboardingOf(tester)!.current, OnboardingStep.basics);
    });

    testWidgets('the question is asked once', (tester) async {
      useTallScreen(tester);
      final h = Harness(analyticsConsent: null);
      await h.pumpApp(tester);
      await tapText(tester, 'Try it first');
      await tester.tap(find.text('I am 16 or older'));
      await tester.pumpAndSettle();
      await tapText(tester, 'No thanks');
      await tester.pumpWidget(const SizedBox());
      final h2 = Harness(store: h.store, analyticsConsent: null);
      await h2.pumpApp(tester);
      expect(find.text('Help us improve'), findsNothing);
    });
  });

  group('Consent centre', () {
    testWidgets(
      'AI-training opt-out is ON by default; toggles sync with timestamps server-side',
      (tester) async {
        final h = await signedInHome(tester);
        await openSettings(tester);
        await tapText(tester, 'Privacy choices');
        final ai = tester.widget<SwitchListTile>(
          find.widgetWithText(
            SwitchListTile,
            'Do not use my photos to train AI models',
          ),
        );
        expect(ai.value, isTrue);
        expect(find.textContaining('approximate location'), findsOneWidget);
        expect(find.text('Policy version 2026-01'), findsOneWidget);

        await tester.tap(
          find.widgetWithText(
            SwitchListTile,
            'Do not use my photos to train AI models',
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(
            SwitchListTile,
            'Share anonymous usage analytics',
          ),
        );
        await tester.pumpAndSettle();
        final server = await h.consents.get();
        expect(server.noAiTraining, isFalse);
        expect(server.analyticsOptIn, isFalse);
        // local copy persisted
        expect(
          jsonDecode(
            h.store.read(ConsentController.storeKey)!,
          )['no_ai_training'],
          isFalse,
        );
      },
    );

    testWidgets('turning analytics off stops events immediately', (
      tester,
    ) async {
      final h = await signedInHome(tester);
      final before = h.analytics.events.length;
      await openSettings(tester);
      await tapText(tester, 'Privacy choices');
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Share anonymous usage analytics'),
      );
      await tester.pumpAndSettle();
      containerOf(
        tester,
      ).read(onboardingControllerProvider.notifier).firstOutfitViewed();
      expect(h.analytics.events.length, before);
    });
  });

  group('Settings', () {
    testWidgets('policy and terms links open the configured URLs', (
      tester,
    ) async {
      final h = await signedInHome(tester);
      await openSettings(tester);
      await tapText(tester, 'Privacy policy');
      await tapText(tester, 'Terms of service');
      expect(h.urls.opened, [
        'https://example.com/privacy',
        'https://example.com/terms',
      ]);
    });

    testWidgets('guest can sign in from settings without losing data', (
      tester,
    ) async {
      final h = await signedInHome(tester, guest: true);
      final guestId = (await h.accounts.me()).id;
      await openSettings(tester);
      expect(find.text("You're using a guest account"), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Sign in with Google'),
      );
      await tester.pumpAndSettle();
      expect(find.text("You're using a guest account"), findsNothing);
      expect(find.textContaining('ada@example.com'), findsOneWidget);
      expect((await h.accounts.me()).id, guestId);
    });

    testWidgets('sign out confirms, wipes this device and returns to welcome', (
      tester,
    ) async {
      final h = await signedInHome(tester);
      await openSettings(tester);
      await tapText(tester, 'Sign out');
      expect(find.text('Sign out?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Try it first'), findsOneWidget);
      expect(h.auth.currentUser, isNull);
      expect(h.store.read(OnboardingController.storeKey), isNull);
      expect(h.store.read(ConsentController.storeKey), isNull);
    });

    testWidgets('signing back in resumes from the server', (tester) async {
      final h = await signedInHome(tester);
      // The server learned about the finished onboarding through the normal sync.
      await h.onboarding.putState({
        'completed': true,
        'completed_steps': ['welcome', 'age'],
      });
      await openSettings(tester);
      await tapText(tester, 'Sign out');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Sign in with Google');
      expect(find.text('Finish setting up'), findsOneWidget);
    });
  });

  group('Export my data', () {
    testWidgets('async job: request, wait, share a JSON file', (tester) async {
      final h = await signedInHome(tester);
      await openSettings(tester);
      await tapText(tester, 'Export my data');
      await tester.tap(find.widgetWithText(FilledButton, 'Request export'));
      await tester.pump();
      expect(find.text('Preparing your export…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Your export is ready.'), findsOneWidget);
      await tapButton(tester, 'Download and share');
      expect(h.sharer.shared, hasLength(1));
      expect(h.sharer.shared.single.filename, 'my-data.json');
      final json =
          jsonDecode(utf8.decode(h.sharer.shared.single.bytes))
              as Map<String, dynamic>;
      expect(json['profile']['city'], 'Austin, TX');
      expect(json['format_version'], 1);
      expect(h.analytics.names, contains(AnalyticsEvent.dataExported));
    });
  });

  group('Delete my account', () {
    testWidgets(
      'needs explicit confirmation, deletes server-side and wipes the device',
      (tester) async {
        final h = await signedInHome(tester);
        await openSettings(tester);
        await tapText(tester, 'Delete my account');
        expect(find.textContaining('within 30 days'), findsOneWidget);
        var btn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Delete my account'),
        );
        expect(btn.onPressed, isNull);
        await tester.enterText(find.byType(TextField), 'nope');
        await tester.pump();
        btn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Delete my account'),
        );
        expect(btn.onPressed, isNull);
        await tester.enterText(find.byType(TextField), 'DELETE');
        await tester.pump();
        await tapButton(tester, 'Delete my account');

        expect(find.text('Try it first'), findsOneWidget); // back at welcome
        expect(find.textContaining('scheduled for deletion'), findsOneWidget);
        expect(h.auth.currentUser, isNull);
        expect(h.analytics.names, contains(AnalyticsEvent.accountDeleted));
        for (final key in [
          OnboardingController.storeKey,
          ConsentController.storeKey,
          'closet_items_v1',
          'session_user_cache',
        ]) {
          expect(h.store.read(key), isNull, reason: key);
        }
      },
    );

    testWidgets('signing in during the 30-day window offers to restore', (
      tester,
    ) async {
      final h = await signedInHome(tester);
      await openSettings(tester);
      await tapText(tester, 'Delete my account');
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tapButton(tester, 'Delete my account');
      await tester.pump(const Duration(seconds: 5)); // let the snackbar go
      await tester.pumpAndSettle();
      await tapText(tester, 'Sign in with Google');
      expect(
        find.text('Your account is scheduled for deletion'),
        findsOneWidget,
      );
      await tapButton(tester, 'Restore my account');
      expect((await h.accounts.me()).status.name, 'active');
    });
  });

  group('Resume', () {
    testWidgets('second device continues where the first stopped', (
      tester,
    ) async {
      useTallScreen(tester);
      final first = Harness();
      await first.pumpApp(tester);
      await tapText(tester, 'Sign in with Google');
      await tester.tap(find.text('I am 16 or older'));
      await tester.pumpAndSettle();
      await answerQuizWomenswear(tester);
      expect(onboardingOf(tester)!.current, OnboardingStep.basics);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());

      // Brand-new device (empty disk), same account and same backend.
      final second = Harness(serverStore: first.store);
      await second.pumpApp(tester);
      await tapText(tester, 'Sign in with Google');
      expect(find.text('A few basics'), findsOneWidget);
      final s = onboardingOf(tester)!;
      expect(
        s.quiz.isComplete,
        isTrue,
        reason: 'quiz answers come back from the server',
      );
      expect(s.quiz.fit?.name, 'slim');
    });
  });
}
