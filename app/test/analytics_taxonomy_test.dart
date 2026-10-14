import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/core/analytics/analytics_service.dart';
import 'package:stylist/core/startup/startup_timer.dart';
import 'package:stylist/features/onboarding/domain/onboarding_state.dart';

import 'flows/closet_journey.dart';
import 'flows/flows.dart';
import 'flows/steps.dart';
import 'helpers/harness.dart';

void main() {
  test('every event is documented in docs/analytics.md', () {
    final doc = File('../docs/analytics.md').readAsStringSync();
    for (final e in AnalyticsEvent.values) {
      expect(
        doc,
        contains('`${e.wireName}`'),
        reason: '${e.wireName} missing from docs',
      );
    }
  });

  testWidgets('the app flows emit every event in the taxonomy', (tester) async {
    final seen = <AnalyticsEvent>{};
    final props = <AnalyticsEvent, Set<String>>{};
    void collect(RecordingAnalytics a) {
      for (final e in a.events) {
        seen.add(e.event);
        (props[e.event] ??= {}).addAll(e.props.keys);
      }
    }

    // 1) Complete guest journey: everything in the funnel.
    final journey = Harness();
    StartupTimer.instance
      ..markMainEntered()
      ..reportFirstFrame();
    await guestJourney(tester, journey);
    collect(journey.analytics);
    await tester.pumpWidget(const SizedBox());

    // 2) Abandonment: background the app mid-quiz.
    final mid = Harness();
    await mid.pumpApp(tester);
    await tapText(tester, 'Sign in with Google');
    await tester.tap(find.text('I am 16 or older'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(
      mid.analytics.names.where((n) => n == AnalyticsEvent.onboardingAbandoned),
      hasLength(1),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(
      mid.analytics.names.where((n) => n == AnalyticsEvent.onboardingAbandoned),
      hasLength(2),
    );
    expect(
      mid.analytics
          .propsOf(AnalyticsEvent.onboardingAbandoned)
          .first['last_step'],
      'quiz',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    collect(mid.analytics);
    await tester.pumpWidget(const SizedBox());

    // 3) Export + delete from settings.
    final done = Harness();
    done.permissions.outcomes[PermissionKind.notifications] =
        PermissionOutcome.denied;
    await done.seedFinishedOnboarding();
    await done.pumpApp(tester);
    // Daily outfit time from Home: notification permission is denied.
    await tapText(tester, 'Daily outfit time');
    await tapButton(tester, 'Save time');
    await tapButton(tester, 'Allow');
    await tapButton(tester, 'Continue');
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Export my data');
    await tester.tap(find.widgetWithText(FilledButton, 'Request export'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tapButton(tester, 'Download and share');
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await tapText(tester, 'Delete my account');
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    await tapButton(tester, 'Delete my account');
    collect(done.analytics);

    // 4) The closet: capture, analysis, corrections, bulk add, filters, limit, delete.
    final closet = await closetJourney(tester);
    expectClosetEvents(closet);
    collect(closet.analytics);

    expect(
      AnalyticsEvent.values.toSet().difference(seen),
      isEmpty,
      reason:
          'events never emitted: ${AnalyticsEvent.values.toSet().difference(seen)}',
    );

    // Property contracts documented in docs/analytics.md.
    expect(props[AnalyticsEvent.onboardingStarted], contains('variant'));
    expect(
      props[AnalyticsEvent.quizQuestionAnswered],
      containsAll(['question', 'index']),
    );
    expect(
      props[AnalyticsEvent.basicsCompleted],
      containsAll(['has_name', 'units', 'has_city']),
    );
    expect(props[AnalyticsEvent.permissionPromptShown], contains('permission'));
    expect(
      props[AnalyticsEvent.firstItemsProgress],
      containsAll(['count', 'unlocked']),
    );
    expect(
      props[AnalyticsEvent.firstOutfitViewed],
      contains('time_to_first_outfit_ms'),
    );
    expect(
      props[AnalyticsEvent.onboardingCompleted],
      containsAll(['duration_ms', 'time_to_first_outfit_ms']),
    );
    expect(props[AnalyticsEvent.onboardingAbandoned], contains('last_step'));
    expect(props[AnalyticsEvent.closetItemCaptureStarted], contains('source'));
    expect(
      props[AnalyticsEvent.closetItemAnalysed],
      containsAll(['status', 'latency_ms', 'confidence_avg']),
    );
    expect(props[AnalyticsEvent.closetItemCorrected], contains('field'));
    expect(props[AnalyticsEvent.closetFilterUsed], contains('kind'));
    expect(
      props[AnalyticsEvent.closetLimitReached],
      containsAll(['limit', 'used']),
    );
    expect(
      props[AnalyticsEvent.closetMeterNudgeShown],
      containsAll(['category', 'outfits_before', 'outfits_after']),
    );
  });

  testWidgets(
    'analytics is identified by internal id only, never email or name',
    (tester) async {
      useTallScreen(tester);
      final h = Harness();
      await h.pumpApp(tester);
      await tapText(tester, 'Sign in with Google');
      final id = (await h.accounts.me()).id;
      expect(h.analytics.userId, id);
      expect(h.analytics.userId, isNot(contains('@')));
      for (final e in h.analytics.events) {
        for (final v in e.props.values) {
          expect('$v', isNot(contains('@')));
          expect('$v', isNot(contains('Ada')));
        }
      }
    },
  );

  testWidgets('no abandonment event once onboarding is finished', (
    tester,
  ) async {
    useTallScreen(tester);
    final h = Harness();
    await h.seedFinishedOnboarding();
    await h.pumpApp(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(
      h.analytics.names,
      isNot(contains(AnalyticsEvent.onboardingAbandoned)),
    );
  });
}
