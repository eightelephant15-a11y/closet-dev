import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';
import 'package:stylist/features/onboarding/domain/onboarding_state.dart';

/// Reusable UI steps shared by widget tests and integration_test flows.

Future<void> pick(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel('$label, not selected'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> tapButton(WidgetTester tester, String text) async {
  await tester.tap(find.widgetWithText(FilledButton, text));
  await tester.pumpAndSettle();
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

OnboardingState? onboardingOf(WidgetTester tester) =>
    containerOf(tester).read(onboardingControllerProvider);

/// Answers all six quiz questions as a womenswear / slim / navy+olive user.
Future<void> answerQuizWomenswear(WidgetTester tester) async {
  await pick(tester, 'Womenswear');
  await pick(tester, 'Slim');
  await pick(tester, 'Navy');
  await pick(tester, 'Olive');
  await tapButton(tester, 'Next');
  await pick(tester, 'Heels');
  await tapButton(tester, 'Next');
  await pick(tester, 'Smart casual');
  await pick(tester, 'Work');
  await pick(tester, 'Travel');
  await tapButton(tester, 'Finish');
}

Future<void> fillBasics(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextField, 'Your name'), 'Ada');
  await tester.enterText(find.widgetWithText(TextField, 'City'), 'aus');
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tapText(tester, 'Austin, TX');
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Continue'));
  await tapButton(tester, 'Continue');
}

/// Allows every primer in the permissions step.
Future<void> allowPermissions(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tapButton(tester, 'Allow');
    await tapButton(tester, 'Continue');
  }
}

/// Basics -> permissions -> items -> outfit screen (using the sample closet).
Future<void> throughToFirstOutfit(WidgetTester tester) async {
  await fillBasics(tester);
  await allowPermissions(tester);
  await tapButton(tester, 'Use sample closet');
  await tapButton(tester, 'See my first outfit');
}

bool isPermissionGranted(OnboardingState s, PermissionKind k) =>
    s.permissions[k] == PermissionOutcome.granted;

extension SettleX on WidgetTester {
  Future<void> settle() => pumpAndSettle();
}

Finder byTextContaining(String t) => find.textContaining(t);

const Key noKey = Key('none');
