import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/features/closet/application/closet_providers.dart';
import 'package:stylist/features/closet/application/image_source.dart';
import 'package:stylist/features/closet/domain/closet_query.dart';
import 'package:stylist/features/closet/domain/garment.dart';
import 'package:stylist/features/config/domain/remote_config.dart';

import '../helpers/closet_helpers.dart';
import '../helpers/harness.dart';

Future<void> seed(WidgetTester tester) async {
  final c = appContainer(tester);
  await c.read(garmentRepositoryProvider).seedSample();
  c
    ..invalidate(closetListProvider)
    ..invalidate(closetSummaryProvider);
  await tester.pumpAndSettle();
}

Future<void> openFirstTile(WidgetTester tester, String name) =>
    scrollTap(tester, find.text(name));

void main() {
  testWidgets('detail: favourite, unavailable with return date, archive', (
    tester,
  ) async {
    final h = await openCloset(tester);
    await seed(tester);
    await openFirstTile(tester, 'Navy Jeans');
    expect(find.text('Navy Jeans'), findsWidgets);

    await tester.tap(find.byTooltip('Add to favourites'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove from favourites'), findsOneWidget);

    await tapSemantic(tester, 'In the laundry, not selected');
    expect(find.text('Set a return date'), findsOneWidget);
    await tester.tap(find.text('Set a return date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Back on'), findsOneWidget);

    final api = backendOf(tester);
    final all = await api.list(const ClosetQuery());
    final jeans = all.items.firstWhere((g) => g.subcategory == 'jeans');
    expect(jeans.favorite, isTrue);
    expect(jeans.availability, Availability.laundry);
    expect(jeans.excludedFromOutfits, isTrue, reason: 'exposed for Phase 3');

    await scrollTap(tester, find.text('Archive'));
    expect(find.text('Restore from archive'), findsOneWidget);
    final active = await api.list(const ClosetQuery());
    expect(active.items.any((g) => g.id == jeans.id), isFalse);
    final archived = await api.list(
      const ClosetQuery(archived: ArchivedMode.only),
    );
    expect(archived.items.map((g) => g.id), contains(jeans.id));
    expect(
      h.analytics.names,
      isNot(contains(AnalyticsEvent.closetItemDeleted)),
    );
    await unmount(tester);
  });

  testWidgets('detail: delete asks first, then removes item and photos', (
    tester,
  ) async {
    final h = await openCloset(tester);
    // a real (uploaded) garment so there are stored images to delete
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this photo'));
    await tester.pumpAndSettle();
    await settleCloset(tester);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(
      h.closetServerBlobs.data.keys.any((k) => k.startsWith('blob/')),
      isTrue,
    );

    await openFirstTile(tester, 'Navy Jeans');
    await scrollTap(tester, find.widgetWithText(TextButton, 'Delete item'));
    expect(find.text('Delete this item?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this item?'), findsNothing);

    await scrollTap(tester, find.widgetWithText(TextButton, 'Delete item'));
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Your closet is empty'), findsOneWidget);
    expect(
      h.closetServerBlobs.data.keys.where((k) => k.startsWith('blob/')),
      isEmpty,
      reason: 'stored images are deleted with the item',
    );
    expect(h.analytics.names, contains(AnalyticsEvent.closetItemDeleted));
    await unmount(tester);
  });

  testWidgets('review keeps corrections made before the garment exists', (
    tester,
  ) async {
    final h = await openCloset(tester);
    backendOf(tester).offline = true;
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this photo'));
    await tester.pumpAndSettle();

    // nothing on the server yet, but the user can already pick a type
    await tapSemantic(tester, 'Bottom, not selected');
    await tapSemantic(tester, 'Chinos, not selected');
    backendOf(tester).offline = false;
    await appContainer(tester).read(uploadQueueProvider).resume();
    await settleCloset(tester, seconds: 10);
    final all = await backendOf(tester).list(const ClosetQuery());
    expect(all.items.single.subcategory, 'chinos');
    expect(h.queueBlobs.data, isEmpty);
    await unmount(tester);
  });

  testWidgets('low-confidence fields are flagged for checking', (tester) async {
    final h = await openCloset(tester);
    h.camera.photos
      ..clear()
      ..add(
        photoNamed('green_hoodie.jpg'),
      ); // no formality in the name -> unsure
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this photo'));
    await tester.pumpAndSettle();
    await settleCloset(tester);
    expect(find.text('Please check'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('free limit: friendly stop, event, nothing uploaded', (
    tester,
  ) async {
    final h = Harness(config: const RemoteConfig(closetItemLimitFree: 1));
    await openCloset(tester, harness: h);
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this photo'));
    await tester.pumpAndSettle();
    await settleCloset(tester);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    expect(find.text('Your free closet is full'), findsWidgets);
    expect(find.textContaining('holds 1 items'), findsOneWidget);
    expect(h.analytics.names, contains(AnalyticsEvent.closetLimitReached));
    await tester.tap(find.text('Manage my closet'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 1 items'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('bulk add: up to 20, queue, review queue, accept all', (
    tester,
  ) async {
    final h = await openCloset(tester);
    h.imageSource.library.addAll([
      for (var i = 0; i < 4; i++) photoNamed('top_navy_f2_$i.jpg', i),
    ]);
    await tester.tap(find.byTooltip('Add several'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Choose up to 20 photos. We upload them in the background and fill in the details.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Choose photos'));
    await tester.pumpAndSettle();
    await settleCloset(tester, seconds: 12);
    expect(find.text('All done'), findsOneWidget);
    expect(find.text('Ready to review'), findsOneWidget);

    await tester.tap(find.text('Accept all'));
    await tester.pumpAndSettle();
    expect(find.text('4 items accepted'), findsOneWidget);
    expect(
      h.analytics.propsOf(AnalyticsEvent.closetBulkAddStarted).single['count'],
      4,
    );
    final done = h.analytics
        .propsOf(AnalyticsEvent.closetBulkAddCompleted)
        .single;
    expect(done['uploaded'], 4);
    expect(done['failed'], 0);
    await unmount(tester);
  });

  testWidgets('bulk add never exceeds the room left on the plan', (
    tester,
  ) async {
    final h = Harness(config: const RemoteConfig(closetItemLimitFree: 3));
    await openCloset(tester, harness: h);
    h.imageSource.library.addAll([
      for (var i = 0; i < 5; i++) photoNamed('tee_$i.jpg', i),
    ]);
    await tester.tap(find.byTooltip('Add several'));
    await tester.pumpAndSettle();
    expect(find.text('You have room for 3 more items.'), findsOneWidget);
    await tester.tap(find.text('Choose photos'));
    await tester.pumpAndSettle();
    await settleCloset(tester, seconds: 12);
    expect(find.textContaining('We kept the first 3'), findsOneWidget);
    final all = await backendOf(tester).list(const ClosetQuery());
    expect(all.total, 3);
    await unmount(tester);
  });

  testWidgets('bulk add can be switched off by flag', (tester) async {
    final h = Harness(config: const RemoteConfig(closetBulkAddEnabled: false));
    await openCloset(tester, harness: h);
    expect(find.byTooltip('Add several'), findsNothing);
    await unmount(tester);
  });

  testWidgets('camera problems fall back to the photo library', (tester) async {
    final h = Harness()..camera = FakeCameraService(failInit: true);
    await openCloset(tester, harness: h);
    h.imageSource.library.add(photoNamed('white_shirt_f3.jpg'));
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    expect(find.textContaining('camera is not available'), findsOneWidget);
    await tester.tap(find.text('Choose from photos'));
    await tester.pumpAndSettle();
    expect(find.text('Use this photo'), findsOneWidget);
    await tester.tap(find.text('Retake'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from photos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this photo'));
    await tester.pumpAndSettle();
    await settleCloset(tester);
    expect(find.bySemanticsLabel('Shirt, selected'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('lighting hint follows the camera', (tester) async {
    final h = await openCloset(tester);
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    expect(find.textContaining('good light'), findsOneWidget);
    h.camera.emit(LightingHint.fromLuminance(20));
    await tester.pumpAndSettle();
    expect(find.text('Too dark. Move somewhere brighter.'), findsOneWidget);
    h.camera.emit(LightingHint.fromLuminance(240));
    await tester.pumpAndSettle();
    expect(find.text('Too bright. Step out of direct sun.'), findsOneWidget);
    h.camera.emit(LightingHint.fromLuminance(130));
    await tester.pumpAndSettle();
    expect(find.text('Lighting looks good.'), findsOneWidget);
    await unmount(tester);
  });
}
