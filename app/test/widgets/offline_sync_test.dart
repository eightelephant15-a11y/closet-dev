import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/core/providers.dart';

import '../flows/steps.dart';
import '../helpers/harness.dart';

void main() {
  testWidgets(
    'onboarding done offline queues locally and syncs when the network returns',
    (tester) async {
      useTallScreen(tester);
      final h = Harness();
      await h.pumpApp(tester);
      await tapText(tester, 'Try it first');
      h.onboarding.offline = true;
      h.accounts.offline = true;

      await tester.tap(find.text('I am 16 or older'));
      await tester.pumpAndSettle();
      await answerQuizWomenswear(tester);
      await tapText(tester, 'Skip'); // basics

      // The user keeps moving forward while offline.
      expect(find.text('Photograph your clothes'), findsOneWidget);
      final box = containerOf(tester).read(outboxProvider);
      expect(box.pending, isNotEmpty);
      expect(h.onboarding.ageConfirmed, isFalse);
      expect(
        await h.onboarding
            .getPreferenceAnswers()
            .then((_) => 1)
            .onError((_, _) => 0),
        0,
      );

      // Back online: a connectivity event flushes everything.
      h.onboarding.offline = false;
      h.accounts.offline = false;
      h.connectivity.add(null);
      await tester.pumpAndSettle();
      expect(box.pending, isEmpty);
      expect(h.onboarding.ageConfirmed, isTrue);
      final answers = await h.onboarding.getPreferenceAnswers();
      expect(answers['department'], 'womenswear');
      expect(answers['goals'], ['travel', 'work']);
      expect(h.onboarding.puts.last['current_step'], 'permissions');
      expect((await h.accounts.me()).clothingDepartment?.name, 'womenswear');
    },
  );

  testWidgets('returning to the foreground also flushes', (tester) async {
    useTallScreen(tester);
    final h = Harness();
    await h.pumpApp(tester);
    await tapText(tester, 'Try it first');
    h.onboarding.offline = true;
    await tester.tap(find.text('I am 16 or older'));
    await tester.pumpAndSettle();
    final box = containerOf(tester).read(outboxProvider);
    expect(box.pending, isNotEmpty);
    h.onboarding.offline = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(box.pending, isEmpty);
  });
}
