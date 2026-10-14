import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/features/config/domain/remote_config.dart';

import '../helpers/closet_helpers.dart';
import '../helpers/harness.dart';

/// Add one item with the camera and correct it, add four more in bulk, filter, hit the free limit,
/// then delete one. Touches every closet analytics event.
Future<Harness> closetJourney(WidgetTester tester) async {
  await unmount(tester); // never reuse a tree left behind by another journey
  final h = Harness(config: const RemoteConfig(closetItemLimitFree: 5));
  await openCloset(tester, harness: h);

  // 1) camera add + one-tap correction
  await tester.tap(find.text('Add item'));
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel('Take photo'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Use this photo'));
  await tester.pumpAndSettle();
  await settleCloset(tester);
  await tapSemantic(tester, 'Black, not selected');
  await scrollTap(tester, find.text('Looks good'));
  await settleCloset(tester, seconds: 1);

  // 2) bulk add: three tops and a pair of shoes
  h.imageSource.library.addAll([
    photoNamed('shirt_white_f3.jpg', 1),
    photoNamed('shirt_blue_f3.jpg', 2),
    photoNamed('t_shirt_grey_f1.jpg', 3),
    photoNamed('sneakers_white_f2.jpg', 4),
  ]);
  await tester.tap(find.byTooltip('Add several'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Choose photos'));
  await tester.pumpAndSettle();
  await settleCloset(tester, seconds: 12);
  await tester.tap(find.text('Accept all'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open my closet'));
  await tester.pumpAndSettle();
  await settleCloset(tester, seconds: 1);

  // 3) filters
  await tester.tap(find.bySemanticsLabel('Top, not selected'));
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel('All, not selected').first);
  await tester.pumpAndSettle();

  // 4) free limit
  await tester.tap(find.text('Add item'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Manage my closet'));
  await tester.pumpAndSettle();

  // 5) delete
  await tester.tap(find.text('White Shirt').first);
  await tester.pumpAndSettle();
  await scrollTap(tester, find.widgetWithText(TextButton, 'Delete item'));
  await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
  await tester.pumpAndSettle();
  await unmount(tester);
  return h;
}

void expectClosetEvents(Harness h) {
  final names = h.analytics.names;
  for (final e in [
    AnalyticsEvent.closetItemCaptureStarted,
    AnalyticsEvent.closetItemUploaded,
    AnalyticsEvent.closetItemAnalysed,
    AnalyticsEvent.closetItemCorrected,
    AnalyticsEvent.closetBulkAddStarted,
    AnalyticsEvent.closetBulkAddCompleted,
    AnalyticsEvent.closetFilterUsed,
    AnalyticsEvent.closetLimitReached,
    AnalyticsEvent.closetMeterNudgeShown,
    AnalyticsEvent.closetItemDeleted,
  ]) {
    expect(names, contains(e), reason: '$e missing');
  }
}
