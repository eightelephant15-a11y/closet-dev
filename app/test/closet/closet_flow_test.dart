import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/features/closet/application/closet_providers.dart';

import '../flows/steps.dart';
import '../helpers/closet_helpers.dart';

void main() {
  testWidgets('empty closet invites the first item', (tester) async {
    await openCloset(tester);
    expect(find.text('Your closet is empty'), findsOneWidget);
    expect(find.text('Add item'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'camera -> review: AI fills details, one tap corrects, item shows in closet',
    (tester) async {
      final h = await openCloset(tester);
      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();
      expect(find.text('Add an item'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Take photo'));
      await tester.pumpAndSettle();
      expect(find.text('Use this photo'), findsOneWidget);
      await tester.tap(find.text('Use this photo'));
      await tester.pumpAndSettle();

      // Review opens immediately, before the AI has answered.
      expect(find.text('Check the details'), findsOneWidget);
      await settleCloset(tester);
      expect(find.textContaining('We filled in the details'), findsOneWidget);
      // jeans / navy / formality 2 came from the file name.
      expect(
        find.bySemanticsLabel('Jeans, selected'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Navy, selected'), findsWidgets);

      // One tap to correct the main colour to Black.
      await tester.ensureVisible(
        find.bySemanticsLabel('Black, not selected').first,
      );
      await tester.tap(find.bySemanticsLabel('Black, not selected').first);
      await tester.pumpAndSettle();
      expect(
        h.analytics.propsOf(AnalyticsEvent.closetItemCorrected).first['field'],
        'primary_color',
      );

      await tester.scrollUntilVisible(
        find.text('Looks good'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Looks good'));
      await settleCloset(tester, seconds: 1);
      expect(find.text('Black Jeans'), findsOneWidget);

      final names = h.analytics.names;
      expect(
        names,
        containsAllInOrder([
          AnalyticsEvent.closetItemCaptureStarted,
          AnalyticsEvent.closetItemUploaded,
          AnalyticsEvent.closetItemAnalysed,
          AnalyticsEvent.closetItemCorrected,
        ]),
      );
      final analysed = h.analytics
          .propsOf(AnalyticsEvent.closetItemAnalysed)
          .first;
      expect(analysed['status'], 'done');
      expect(analysed, contains('latency_ms'));
      expect(analysed, contains('confidence_avg'));
      await unmount(tester);
    },
  );

  testWidgets(
    'offline: the photo is kept and uploads when the network returns',
    (tester) async {
      final h = await openCloset(tester);
      backendOf(tester).offline = true;
      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Take photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this photo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Waiting for a connection'), findsWidgets);
      expect(h.queueBlobs.data, isNotEmpty);

      backendOf(tester).offline = false;
      await containerOf(tester).read(uploadQueueProvider).resume();
      await settleCloset(tester);
      expect(find.textContaining('We filled in the details'), findsOneWidget);
      expect(h.queueBlobs.data, isEmpty);
      await unmount(tester);
    },
  );

  testWidgets('sample closet is real garments with bundled pictures', (
    tester,
  ) async {
    await openCloset(tester);
    await containerOf(tester).read(garmentRepositoryProvider).seedSample();
    containerOf(tester).invalidate(closetListProvider);
    containerOf(tester).invalidate(closetSummaryProvider);
    await tester.pumpAndSettle();
    expect(find.text('White Shirt'), findsOneWidget);
    // Sample garments never count against the plan limit.
    expect(find.text('0 of 30 items'), findsOneWidget);
    expect(find.textContaining('possible outfits'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('filters, search and sort narrow the grid', (tester) async {
    await openCloset(tester);
    final c = containerOf(tester);
    await c.read(garmentRepositoryProvider).seedSample();
    c.invalidate(closetListProvider);
    c.invalidate(closetSummaryProvider);
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Top, not selected'));
    await tester.pumpAndSettle();
    expect(find.text('White Shirt'), findsOneWidget);
    expect(find.text('Navy Jeans'), findsNothing);

    await tester.tap(find.bySemanticsLabel('All, not selected').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search your closet'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'jeans');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(c.read(closetQueryProvider).text, 'jeans');
    expect(find.text('Navy Jeans'), findsOneWidget);
    expect(find.text('White Shirt'), findsNothing);
    await unmount(tester);
  });
}
