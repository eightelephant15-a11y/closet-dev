import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/features/auth/application/session_controller.dart';
import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/onboarding/domain/onboarding_state.dart';
import 'package:stylist/features/onboarding/domain/onboarding_step.dart';

import '../helpers/harness.dart';
import 'steps.dart';

/// Full guest journey, ending with the guest upgrading to a Google account
/// when they try to save, with no data lost.
Future<void> guestJourney(WidgetTester tester, Harness h) async {
  useTallScreen(tester);
  await h.pumpApp(tester);

  await tapText(tester, 'Try it first');
  expect(find.text('I am 16 or older'), findsOneWidget);
  final guestId = (await h.accounts.me()).id;
  expect(h.auth.currentUser!.isAnonymous, isTrue);

  await tapText(tester, 'I am 16 or older');
  await answerQuizWomenswear(tester);
  await throughToFirstOutfit(tester);

  // First outfit: one + two alternatives, each with a why line.
  expect(find.text('Your first outfit'), findsOneWidget);
  expect(find.text('Outfit 1'), findsOneWidget);
  expect(find.text('Two more ideas'), findsOneWidget);
  expect(find.text('Outfit 3'), findsOneWidget);
  expect(find.textContaining('Built around'), findsWidgets);

  // Saving as a guest prompts sign-in, then upgrades in place.
  await tester.tap(find.text('Save outfit').first);
  await tester.pumpAndSettle();
  expect(find.text('Sign in to save'), findsOneWidget);
  await tapButton(tester, 'Continue with Google');
  expect(find.text('Outfit saved'), findsWidgets);
  final upgraded = containerOf(tester).read(sessionControllerProvider);
  expect(upgraded.status, SessionStatus.member);
  expect(upgraded.user!.id, guestId, reason: 'upgrade must keep the same user');
  expect(upgraded.user!.city, 'Austin, TX');
  expect(upgraded.user!.clothingDepartment, ClothingDepartment.womenswear);
  expect(onboardingOf(tester)!.quiz.isComplete, isTrue);

  await tapButton(tester, 'Continue');
  expect(find.text('Two optional extras'), findsOneWidget);
  await tapText(tester, 'Finish setup');
  expect(find.text('Hi, Ada'), findsOneWidget);

  // Server-side view agrees.
  final answers = await h.onboarding.getPreferenceAnswers();
  expect(answers['department'], 'womenswear');
  expect(answers['colors'], ['navy', 'olive']);
  expect(h.onboarding.puts.last['completed'], isTrue);

  expectFunnel(h, hadGuest: true);
}

/// Full Google sign-in journey (no guest step, no save prompt).
Future<void> googleJourney(WidgetTester tester, Harness h) async {
  useTallScreen(tester);
  await h.pumpApp(tester);

  await tapText(tester, 'Sign in with Google');
  expect(h.auth.currentUser!.isAnonymous, isFalse);
  await tapText(tester, 'I am 16 or older');
  await answerQuizWomenswear(tester);
  await throughToFirstOutfit(tester);

  await tester.tap(find.text('Save outfit').first);
  await tester.pumpAndSettle();
  expect(find.text('Sign in to save'), findsNothing);
  expect(find.text('Outfit saved'), findsWidgets);

  await tapButton(tester, 'Continue');
  await tapText(tester, 'Finish setup');
  expect(find.text('Hi, Ada'), findsOneWidget);
  expectFunnel(h, hadGuest: false);
}

void expectFunnel(Harness h, {required bool hadGuest}) {
  final names = h.analytics.names;
  expect(
    names,
    containsAllInOrder([
      AnalyticsEvent.welcomeViewed,
      if (hadGuest)
        AnalyticsEvent.guestStarted
      else
        AnalyticsEvent.signinStarted,
      AnalyticsEvent.onboardingStarted,
      AnalyticsEvent.ageConfirmed,
      AnalyticsEvent.quizQuestionAnswered,
      AnalyticsEvent.quizCompleted,
      AnalyticsEvent.basicsCompleted,
      AnalyticsEvent.permissionPromptShown,
      AnalyticsEvent.permissionGranted,
      AnalyticsEvent.firstItemsProgress,
      AnalyticsEvent.firstOutfitViewed,
      AnalyticsEvent.onboardingCompleted,
    ]),
  );
  final ttfo = h.analytics
      .propsOf(AnalyticsEvent.firstOutfitViewed)
      .single['time_to_first_outfit_ms'];
  expect(ttfo, isA<int>());
  final completed = h.analytics
      .propsOf(AnalyticsEvent.onboardingCompleted)
      .single;
  expect(completed['time_to_first_outfit_ms'], ttfo);
  expect(
    h.analytics
        .propsOf(AnalyticsEvent.permissionPromptShown)
        .map((p) => p['permission']),
    [
      'camera',
      'photos',
      'location',
    ],
  );
  expect(OnboardingStep.values.length, greaterThan(0));
  expect(PermissionKind.values.length, 4);
}
