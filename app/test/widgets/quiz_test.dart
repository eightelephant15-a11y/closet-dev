import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/core/network/api_exception.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';
import 'package:stylist/features/onboarding/domain/onboarding_step.dart';
import 'package:stylist/features/onboarding/domain/quiz.dart';

import '../helpers/harness.dart';

Future<Harness> toQuiz(WidgetTester tester, {Harness? existing}) async {
  useTallScreen(tester);
  final h = existing ?? Harness();
  await h.pumpApp(tester);
  await tester.tap(find.text('Try it first'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('I am 16 or older'));
  await tester.pumpAndSettle();
  return h;
}

Future<void> pick(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel('$label, not selected'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Next'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Next is disabled until a question is answered', (tester) async {
    await toQuiz(tester);
    final btn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Next'),
    );
    expect(btn.onPressed, isNull);
    expect(find.text('Question 1 of 6'), findsWidgets);
  });

  testWidgets(
    'full 6-question quiz stores answers, syncs and moves to basics',
    (tester) async {
      final h = await toQuiz(tester);

      await pick(tester, 'Womenswear'); // auto-advances
      expect(find.text('How do you like your clothes to fit?'), findsOneWidget);
      await pick(tester, 'Slim');
      expect(find.text('Which colours do you love?'), findsOneWidget);
      await pick(tester, 'Navy');
      await pick(tester, 'Olive');
      await next(tester);
      // Never-wear options adapt: heels offered for womenswear, ties are not.
      expect(find.bySemanticsLabel('Heels, not selected'), findsOneWidget);
      expect(find.bySemanticsLabel('Ties, not selected'), findsNothing);
      await pick(tester, 'Heels');
      await next(tester);
      await pick(tester, 'Smart casual');
      expect(find.text('What do you want help with?'), findsOneWidget);
      await pick(tester, 'Work');
      await pick(tester, 'Travel');
      await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
      await tester.pumpAndSettle();

      final c = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      final s = c.read(onboardingControllerProvider)!;
      expect(s.quiz.isComplete, isTrue);
      expect(s.quiz.department, ClothingDepartment.womenswear);
      expect(s.quiz.fit, Fit.slim);
      expect(s.quiz.colors, {ClothingColor.navy, ClothingColor.olive});
      expect(s.quiz.neverWear, {NeverWear.heels});
      expect(s.quiz.dressCode, 2);
      expect(s.quiz.goals, {Goal.work, Goal.travel});
      expect(s.current, OnboardingStep.basics);
      expect(find.textContaining('basics'), findsOneWidget);

      // Answers reached the (mock) server and the user's department was set.
      await tester.pumpAndSettle();
      final answers = await h.onboarding.getPreferenceAnswers();
      expect(answers['fit'], 'slim');
      expect(answers['never_wear'], ['heels']);
      expect(
        (await h.accounts.me()).clothingDepartment,
        ClothingDepartment.womenswear,
      );

      expect(
        h.analytics.propsOf(AnalyticsEvent.quizQuestionAnswered).length,
        greaterThanOrEqualTo(6),
      );
      expect(h.analytics.names, contains(AnalyticsEvent.quizCompleted));
      expect(
        c.read(keyValueStoreProvider).read(OnboardingController.storeKey),
        isNotNull,
      );
    },
  );

  testWidgets(
    'menswear shows ties but not heels; "nothing" counts as answered',
    (tester) async {
      await toQuiz(tester);
      await pick(tester, 'Menswear');
      await pick(tester, 'Regular');
      await pick(tester, 'Black');
      await next(tester);
      expect(find.bySemanticsLabel('Ties, not selected'), findsOneWidget);
      expect(find.bySemanticsLabel('Heels, not selected'), findsNothing);
      await pick(tester, "Nothing, I'll wear anything");
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('Back returns to the previous card and keeps its answer', (
    tester,
  ) async {
    await toQuiz(tester);
    await pick(tester, 'Both');
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Both, selected'), findsOneWidget);
  });

  testWidgets('swipe forward works only after answering', (tester) async {
    await toQuiz(tester);
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.text('Which clothes should we show you?'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Both, not selected'));
    await tester.pump();
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.text('How do you like your clothes to fit?'), findsOneWidget);
  });

  testWidgets(
    'killing the app mid-quiz resumes at the same question with answers',
    (tester) async {
      final h = await toQuiz(tester);
      await pick(tester, 'Womenswear');
      await pick(tester, 'Relaxed');
      expect(find.text('Which colours do you love?'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      final h2 = Harness(store: h.store);
      await h2.pumpApp(tester);
      expect(find.text('Which colours do you love?'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Relaxed, selected'), findsOneWidget);
    },
  );

  testWidgets('quiz works offline and syncs on reconnect', (tester) async {
    final h = await toQuiz(tester);
    h.onboarding.offline = true;
    await pick(tester, 'Womenswear');
    await pick(tester, 'Slim');
    await expectLater(
      h.onboarding.getPreferenceAnswers(),
      throwsA(isA<ApiException>()),
    );

    h.onboarding.offline = false;
    final c = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    await c.read(outboxProvider).flush();
    final answers = await h.onboarding.getPreferenceAnswers();
    expect(answers['department'], 'womenswear');
    expect(answers['fit'], 'slim');
    expect(c.read(outboxProvider).pending, isEmpty);
  });

  testWidgets('selection state is exposed to screen readers', (tester) async {
    await toQuiz(tester);
    final handle = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Both, not selected'));
    await tester.pump();
    final node = tester.getSemantics(find.bySemanticsLabel('Both, selected'));
    expect(node.flagsCollection.isSelected, isNotNull);
    handle.dispose();
  });
}
