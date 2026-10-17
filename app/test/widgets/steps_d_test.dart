import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/config/domain/remote_config.dart';
import 'package:stylist/features/onboarding/domain/onboarding_state.dart';
import 'package:stylist/features/onboarding/domain/onboarding_step.dart';

import '../flows/steps.dart';
import '../helpers/harness.dart';

Future<Harness> toStep(
  WidgetTester tester, {
  Harness? h,
  bool quiz = true,
}) async {
  useTallScreen(tester);
  final harness = h ?? Harness();
  await harness.pumpApp(tester);
  await tapText(tester, 'Try it first');
  await tapText(tester, 'I am 16 or older');
  if (quiz) await answerQuizWomenswear(tester);
  return harness;
}

void main() {
  group('Basics', () {
    testWidgets('city autocomplete picks a city; data is saved and synced', (
      tester,
    ) async {
      final h = await toStep(tester);
      expect(find.text('A few basics'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Your name'),
        'Grace',
      );
      await tester.tap(find.text('Metric (cm, kg, °C)'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'City'), 'sea');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tapText(tester, 'Seattle, WA');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Continue'));
      await tapButton(tester, 'Continue');

      final s = onboardingOf(tester)!;
      expect(
        (s.displayName, s.units, s.city),
        ('Grace', Units.metric, 'Seattle, WA'),
      );
      expect(s.current, OnboardingStep.permissions);
      final me = await h.accounts.me();
      expect(
        (me.displayName, me.units, me.city),
        ('Grace', Units.metric, 'Seattle, WA'),
      );
      final props = h.analytics.propsOf(AnalyticsEvent.basicsCompleted).single;
      expect(props, {'has_name': true, 'units': 'metric', 'has_city': true});
    });

    testWidgets('imperial is the default and everything is skippable', (
      tester,
    ) async {
      await toStep(tester);
      await tapText(tester, 'Skip');
      final s = onboardingOf(tester)!;
      expect(s.units, Units.imperial);
      expect(s.current, OnboardingStep.permissions);
    });

    testWidgets('prefills the name from the Google account', (tester) async {
      useTallScreen(tester);
      final h = Harness();
      await h.pumpApp(tester);
      await tapText(tester, 'Sign in with Google');
      await tapText(tester, 'I am 16 or older');
      await answerQuizWomenswear(tester);
      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Your name'),
      );
      expect(field.controller!.text, 'Ada Lovelace');
    });

    testWidgets('no matches hint, and typing still works', (tester) async {
      await toStep(tester);
      await tester.enterText(find.widgetWithText(TextField, 'City'), 'zzzz');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(
        find.text('No matches. You can keep what you typed.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Continue'));
      await tapButton(tester, 'Continue');
      expect(onboardingOf(tester)!.city, 'zzzz');
    });
  });

  group('Permission priming', () {
    testWidgets('primes camera, photos, location in turn, each with a reason', (
      tester,
    ) async {
      final h = await toStep(tester);
      await tapText(tester, 'Skip'); // basics
      expect(find.text('Photograph your clothes'), findsOneWidget);
      expect(
        find.textContaining('camera so you can add clothes'),
        findsOneWidget,
      );
      expect(
        h.permissions.requested,
        isEmpty,
        reason: 'no OS prompt before the user agrees',
      );
      await tapButton(tester, 'Allow');
      expect(find.text('Allowed. Thanks!'), findsOneWidget);
      await tapButton(tester, 'Continue');
      expect(find.text('Pick photos from your library'), findsOneWidget);
      await tapText(tester, 'Not now');
      expect(find.text('Weather-aware outfits'), findsOneWidget);
      await tapButton(tester, 'Allow');
      await tapButton(tester, 'Continue');
      expect(onboardingOf(tester)!.current, OnboardingStep.firstItems);
      final p = onboardingOf(tester)!.permissions;
      expect(p[PermissionKind.camera], PermissionOutcome.granted);
      expect(p[PermissionKind.photos], PermissionOutcome.skipped);
      expect(
        h.analytics.names.where(
          (n) => n == AnalyticsEvent.permissionPromptShown,
        ),
        hasLength(3),
      );
      expect(h.analytics.names, contains(AnalyticsEvent.permissionGranted));
    });

    testWidgets('denial leaves a working fallback and the flow continues', (
      tester,
    ) async {
      final h = Harness();
      h.permissions.outcomes
        ..[PermissionKind.camera] = PermissionOutcome.denied
        ..[PermissionKind.photos] = PermissionOutcome.denied
        ..[PermissionKind.location] = PermissionOutcome.denied;
      await toStep(tester, h: h);
      await tapText(tester, 'Skip');
      await tapButton(tester, 'Allow');
      expect(
        find.textContaining('use the sample closet or add photos'),
        findsOneWidget,
      );
      expect(find.text('Open settings'), findsOneWidget);
      await tapText(tester, 'Open settings');
      expect(h.permissions.settingsOpened, 1);
      await tapButton(tester, 'Continue');
      await tapButton(tester, 'Allow');
      await tapButton(tester, 'Continue');
      await tapButton(tester, 'Allow');
      expect(find.textContaining('Type your city'), findsOneWidget);
      await tapButton(tester, 'Continue');
      expect(
        h.analytics.names.where((n) => n == AnalyticsEvent.permissionDenied),
        hasLength(3),
      );

      // Even with everything denied the user can still unlock via the sample closet.
      await tapButton(tester, 'Use sample closet');
      expect(
        find.text('Ready! Your first outfit is unlocked.'),
        findsOneWidget,
      );
    });

    testWidgets('already-granted permissions are not primed again', (
      tester,
    ) async {
      final h = Harness();
      h.permissions.requested.addAll([
        PermissionKind.camera,
        PermissionKind.photos,
      ]);
      await toStep(tester, h: h);
      await tapText(tester, 'Skip');
      expect(find.text('Weather-aware outfits'), findsOneWidget);
    });
  });

  group('First items shell', () {
    testWidgets('shows ring, unlock rule and a disabled camera button', (
      tester,
    ) async {
      await toStep(tester);
      await tapText(tester, 'Skip');
      await allowPermissions(tester);
      expect(find.text('Add your first 10 items'), findsWidgets);
      expect(find.text('0 of 10 items'), findsWidgets);
      expect(find.text('Tops'), findsOneWidget);
      expect(find.text('0 of 2 added'), findsNWidgets(2));
      expect(find.text('Bottoms'), findsOneWidget);
      expect(find.text('A dress'), findsOneWidget);
      final see = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'See my first outfit'),
      );
      expect(see.onPressed, isNull);
      expect(find.text('Add with camera'), findsOneWidget);
      expect(find.text('Add from photos'), findsOneWidget);
    });

    testWidgets('sample closet fills the ring and unlocks; respects never-wear', (
      tester,
    ) async {
      final h = await toStep(tester);
      await tapText(tester, 'Skip');
      await allowPermissions(tester);
      await tapButton(tester, 'Use sample closet');
      // womenswear minus heels (never-wear) => 16 items - 1 heels - nothing else tagged = 15
      expect(find.text('10 of 10 items'), findsWidgets);
      expect(
        find.text('Ready! Your first outfit is unlocked.'),
        findsOneWidget,
      );
      expect(onboardingOf(tester)!.usedSampleCloset, isTrue);
      final progress = h.analytics
          .propsOf(AnalyticsEvent.firstItemsProgress)
          .last;
      expect(progress['unlocked'], isTrue);
      expect(progress['count'], 15);
    });
  });

  group('First outfit', () {
    testWidgets(
      'three outfits with why lines; time-to-first-outfit recorded once',
      (tester) async {
        final h = await toStep(tester);
        await throughToFirstOutfit(tester);
        expect(find.text('Outfit 1'), findsOneWidget);
        expect(find.text('Outfit 2'), findsOneWidget);
        expect(find.text('Outfit 3'), findsOneWidget);
        expect(find.textContaining('favourite colours'), findsWidgets);
        // Heels were excluded by the quiz.
        expect(find.text('Black block heels'), findsNothing);
        final events = h.analytics
            .propsOf(AnalyticsEvent.firstOutfitViewed)
            .toList();
        expect(events, hasLength(1));
        expect(events.single['time_to_first_outfit_ms'], isA<int>());
        expect(
          onboardingOf(tester)!.timeToFirstOutfitMs,
          events.single['time_to_first_outfit_ms'],
        );
        // The server got it too.
        await tester.pumpAndSettle();
        expect(
          h.onboarding.puts.any((p) => p['time_to_first_outfit_ms'] != null),
          isTrue,
        );
      },
    );
  });

  group('Optional steps', () {
    testWidgets(
      'partner is a placeholder, notification time prompts in context, both skippable',
      (tester) async {
        final h = await toStep(tester);
        await throughToFirstOutfit(tester);
        await tapButton(tester, 'Continue');
        expect(find.text('Two optional extras'), findsOneWidget);

        await tapText(tester, 'Invite a partner');
        expect(find.textContaining('coming soon'), findsWidgets);
        await tapText(tester, 'Got it');

        await tapText(tester, 'Daily outfit time');
        expect(find.text('When should we send your outfit?'), findsOneWidget);
        await tapButton(tester, 'Save time');
        // Notification permission is primed here, in context.
        expect(find.text('Your daily outfit'), findsOneWidget);
        await tapButton(tester, 'Allow');
        await tapButton(tester, 'Continue');
        expect(onboardingOf(tester)!.notificationTime, '08:00');
        expect((await h.accounts.me()).dailyOutfitTime, '08:00');
        expect(find.text('Set for 08:00'), findsOneWidget);

        await tapText(tester, 'Finish setup');
        expect(find.text('Finish setting up'), findsOneWidget); // Home
        expect(h.analytics.names, contains(AnalyticsEvent.onboardingCompleted));
      },
    );

    testWidgets(
      'can skip both and revisit from Home; denial still saves the time',
      (tester) async {
        final h = Harness();
        h.permissions.outcomes[PermissionKind.notifications] =
            PermissionOutcome.denied;
        await toStep(tester, h: h);
        await throughToFirstOutfit(tester);
        await tapButton(tester, 'Continue');
        await tapText(tester, 'Finish setup');
        expect(find.text('Finish setting up'), findsOneWidget);
        await tapText(tester, 'Daily outfit time');
        await tapButton(tester, 'Save time');
        await tapButton(tester, 'Allow');
        expect(
          find.textContaining("You'll see your daily outfit"),
          findsOneWidget,
        );
        await tapButton(tester, 'Continue');
        expect(onboardingOf(tester)!.notificationTime, '08:00');
        expect(find.text('Finish setting up'), findsOneWidget);
      },
    );
  });

  group('Variants and resume', () {
    testWidgets('closet_first puts the quiz after the first items', (
      tester,
    ) async {
      final h = Harness(
        config: const RemoteConfig(
          onboardingVariant: OnboardingVariant.closetFirst,
        ),
      );
      await toStep(tester, h: h, quiz: false);
      expect(find.text('A few basics'), findsOneWidget); // no quiz yet
      await tapText(tester, 'Skip');
      await allowPermissions(tester);
      expect(find.text('Add your first 10 items'), findsWidgets);
      await tapButton(tester, 'Use sample closet');
      await tapButton(tester, 'See my first outfit');
      expect(find.text('Which clothes should we show you?'), findsOneWidget);
      await answerQuizWomenswear(tester);
      expect(find.text('Your first outfit'), findsOneWidget);
    });

    testWidgets('kill mid-flow at first items and resume on the same step', (
      tester,
    ) async {
      final h = await toStep(tester);
      await tapText(tester, 'Skip');
      await allowPermissions(tester);
      await tapButton(tester, 'Use sample closet');
      await tester.pumpWidget(const SizedBox());

      final h2 = Harness(store: h.store);
      await h2.pumpApp(tester);
      expect(find.text('Add your first 10 items'), findsWidgets);
      expect(
        find.text('Ready! Your first outfit is unlocked.'),
        findsOneWidget,
      );
    });

    testWidgets('resume deep link goes to the saved step', (tester) async {
      final h = await toStep(tester);
      await tapText(tester, 'Skip');
      expect(find.text('Photograph your clothes'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      final h2 = Harness(store: h.store);
      await h2.pumpApp(tester);
      expect(find.text('Photograph your clothes'), findsOneWidget);
    });
  });
}
