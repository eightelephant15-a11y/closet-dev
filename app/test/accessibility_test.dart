import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/features/closet/application/closet_providers.dart';
import 'package:stylist/features/config/domain/remote_config.dart';

import 'helpers/closet_helpers.dart';
import 'helpers/harness.dart';

/// Walks the whole onboarding (and the account screens) on a phone-sized surface at several text
/// scales and in both themes. On every screen it enforces Flutter's accessibility guidelines:
/// 48dp (Android) and 44pt (iOS) tap targets, labelled tap targets (screen-reader names), WCAG AA text
/// contrast, and no layout overflow at 100%, 150% and 200% text size.
Future<void> audit(WidgetTester tester, String where) async {
  await tester.pumpAndSettle();
  expect(
    tester.takeException(),
    isNull,
    reason: 'exception/overflow on "$where"',
  );
  await expectLater(
    tester,
    meetsGuideline(androidTapTargetGuideline),
    reason: where,
  );
  await expectLater(
    tester,
    meetsGuideline(iOSTapTargetGuideline),
    reason: where,
  );
  await expectLater(
    tester,
    meetsGuideline(labeledTapTargetGuideline),
    reason: where,
  );
  await expectLater(
    tester,
    meetsGuideline(textContrastGuideline),
    reason: where,
  );
}

void phone(
  WidgetTester tester, {
  required double textScale,
  required Brightness brightness,
}) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });
}

/// Brings [f] on screen, scrolling the page's vertical list if the item is not built yet.
Future<void> reveal(WidgetTester tester, Finder f) async {
  var built = true;
  try {
    built = f.evaluate().isNotEmpty;
    // `.first` on an empty finder throws a StateError.
    // ignore: avoid_catching_errors
  } on StateError {
    built = false; // `.first` on an empty finder
  }
  if (!built) {
    final vertical = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: vertical.first,
      maxScrolls: 60,
    );
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder f) async {
  await reveal(tester, f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> tapLabel(WidgetTester tester, String text) =>
    tapVisible(tester, find.text(text));

Future<void> pickVisible(WidgetTester tester, String label) async {
  await tapVisible(tester, find.bySemanticsLabel('$label, not selected'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

Future<void> next(WidgetTester tester) =>
    tapVisible(tester, find.widgetWithText(FilledButton, 'Next'));

Future<void> tour(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  final h = Harness(analyticsConsent: null);
  await h.pumpApp(tester);

  await audit(tester, 'welcome');
  await tapLabel(tester, 'Try it first');
  await audit(tester, 'age gate');
  await tapLabel(tester, 'I am 16 or older');
  await audit(tester, 'analytics consent dialog');
  await tapLabel(tester, 'Allow analytics');

  // Quiz: audit every card, answering as we go.
  await audit(tester, 'quiz 1 department');
  await pickVisible(tester, 'Womenswear');
  await audit(tester, 'quiz 2 fit');
  await pickVisible(tester, 'Slim');
  await audit(tester, 'quiz 3 colours');
  await pickVisible(tester, 'Navy');
  await next(tester);
  await audit(tester, 'quiz 4 never wear');
  await pickVisible(tester, 'Heels');
  await next(tester);
  await audit(tester, 'quiz 5 dress code');
  await pickVisible(tester, 'Smart casual');
  await audit(tester, 'quiz 6 goals');
  await pickVisible(tester, 'Work');
  await tapVisible(tester, find.widgetWithText(FilledButton, 'Finish'));

  await audit(tester, 'basics');
  await tapLabel(tester, 'Skip');

  for (final name in ['camera', 'photos', 'location']) {
    await audit(tester, 'permission primer: $name');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Allow'));
    await audit(tester, 'permission result: $name');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
  }

  await audit(tester, 'first items (empty)');
  await tapVisible(
    tester,
    find.widgetWithText(FilledButton, 'Use sample closet'),
  );
  await audit(tester, 'first items (unlocked)');
  await tapVisible(
    tester,
    find.widgetWithText(FilledButton, 'See my first outfit'),
  );

  await audit(tester, 'first outfit');
  await tapVisible(tester, find.text('Save outfit').first);
  await audit(tester, 'save sign-in sheet');
  await tapLabel(tester, 'Maybe later');
  await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));

  await audit(tester, 'optional steps');
  await tapLabel(tester, 'Invite a partner');
  await audit(tester, 'partner placeholder');
  await tapLabel(tester, 'Got it');
  await tapLabel(tester, 'Daily outfit time');
  await audit(tester, 'daily outfit time');
  await tapVisible(tester, find.widgetWithText(FilledButton, 'Save time'));
  await audit(tester, 'notification primer');
  await tapVisible(tester, find.widgetWithText(FilledButton, 'Allow'));
  await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
  await tapLabel(tester, 'Finish setup');

  await audit(tester, 'home');
  await tapVisible(tester, find.byTooltip('Settings'));
  await audit(tester, 'settings');
  await tapLabel(tester, 'Privacy choices');
  await audit(tester, 'consent centre');
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await tester.pumpAndSettle();
  await tapLabel(tester, 'Export my data');
  await audit(tester, 'export (idle)');
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await tester.pumpAndSettle();
  await tapLabel(tester, 'Delete my account');
  await audit(tester, 'delete account');
  handle.dispose();
}

/// Every closet screen, at the same text sizes and themes as the onboarding tour.
Future<void> closetTour(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  final h = Harness();
  h.imageSource.library.add(photoNamed('white_shirt_f3.jpg'));
  h.imageProcessor = const InlineImageProcessor();
  await h.seedFinishedOnboarding();
  await h.pumpApp(tester);
  await tapLabel(tester, 'My Closet');
  await audit(tester, 'closet (empty)');

  final c = appContainer(tester);
  await c.read(garmentRepositoryProvider).seedSample();
  c
    ..invalidate(closetListProvider)
    ..invalidate(closetSummaryProvider);
  await tester.pumpAndSettle();
  await audit(tester, 'closet grid');

  await tapVisible(tester, find.byTooltip('Filters'));
  await audit(tester, 'filter sheet');
  Navigator.of(tester.element(find.text('Filters').first)).pop();
  await tester.pumpAndSettle();

  await tapVisible(tester, find.byTooltip('Search your closet'));
  await audit(tester, 'closet search');
  await tapVisible(tester, find.byTooltip('Clear search'));

  await tapLabel(tester, 'Navy Jeans');
  await audit(tester, 'item detail');
  await tapVisible(tester, find.byTooltip('Add to favourites'));
  await tester.pageBack();
  await tester.pumpAndSettle();

  await tapVisible(tester, find.byTooltip('Add several'));
  await audit(tester, 'bulk add (pick)');
  await tapLabel(tester, 'Choose photos');
  await settleCloset(tester, seconds: 6);
  await audit(tester, 'bulk add (review queue)');
  await tapVisible(tester, find.byTooltip('Close'));

  await tapLabel(tester, 'Add item');
  await audit(tester, 'capture (camera)');
  await tapVisible(tester, find.bySemanticsLabel('Take photo'));
  await audit(tester, 'capture (preview)');
  await tapLabel(tester, 'Use this photo');
  await audit(tester, 'review (analysing)');
  await settleCloset(tester);
  await audit(tester, 'review (analysed)');
  await unmount(tester);
  handle.dispose();
}

void main() {
  for (final scale in [1.0, 1.5, 2.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      if (scale == 1.5 && brightness == Brightness.dark) continue;
      testWidgets(
        'closet accessibility tour at ${(scale * 100).round()}% text, ${brightness.name}',
        (tester) async {
          phone(tester, textScale: scale, brightness: brightness);
          await closetTour(tester);
        },
      );
    }
  }

  for (final scale in [1.0, 1.5, 2.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      // 1.5x only in light mode keeps the suite quick; 1x and 2x run in both themes.
      if (scale == 1.5 && brightness == Brightness.dark) continue;
      testWidgets(
        'accessibility tour at ${(scale * 100).round()}% text, ${brightness.name}',
        (
          tester,
        ) async {
          phone(tester, textScale: scale, brightness: brightness);
          await tour(tester);
        },
      );
    }
  }

  group('standalone screens', () {
    testWidgets(
      'sign-in screen (guest mode off) and the under-16 block screen',
      (tester) async {
        for (final scale in [1.0, 2.0]) {
          phone(tester, textScale: scale, brightness: Brightness.light);
          final handle = tester.ensureSemantics();
          final h = Harness(
            config: const RemoteConfig(guestModeEnabled: false),
          );
          await h.pumpApp(tester);
          await audit(tester, 'sign-in @$scale');
          await tapLabel(tester, 'Sign in with Google');
          await tapLabel(tester, 'I am under 16');
          await audit(tester, 'blocked @$scale');
          await tester.pumpWidget(const SizedBox());
          handle.dispose();
        }
      },
    );

    testWidgets('restore-account screen', (tester) async {
      phone(tester, textScale: 2, brightness: Brightness.light);
      final handle = tester.ensureSemantics();
      final h = Harness();
      await h.seedFinishedOnboarding();
      await h.accounts.deleteAccount();
      await h.pumpApp(tester);
      await audit(tester, 'restore account');
      handle.dispose();
    });
  });
}
