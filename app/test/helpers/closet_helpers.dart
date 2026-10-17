import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stylist/features/closet/application/closet_providers.dart';
import 'package:stylist/features/closet/application/image_pipeline.dart';
import 'package:stylist/features/closet/data/mock_closet.dart';

import '../flows/steps.dart';
import 'harness.dart';

/// A tiny valid JPEG; `seed` makes the bytes (and so the fake AI's guesses) differ.
Uint8List jpegBytes([int seed = 0]) {
  final im = img.Image(width: 48, height: 64);
  img.fill(im, color: img.ColorRgb8(30 + seed * 7 % 200, 70, 140));
  return Uint8List.fromList(img.encodeJpg(im));
}

PickedImage photoNamed(String name, [int seed = 0]) =>
    PickedImage(name: name, bytes: jpegBytes(seed));

/// Skips the isolate: widget tests run in fake async where `compute` would hang.
class InlineImageProcessor implements ImageProcessor {
  const InlineImageProcessor();

  @override
  Future<ProcessedPhoto> process(PickedImage image, {CropRect? crop}) async =>
      ProcessedPhoto(
        bytes: image.bytes,
        filename: image.name,
        width: 48,
        height: 64,
      );

  @override
  Future<CropRect?> suggestCrop(PickedImage image) async => null;
}

MockClosetBackend backendOf(WidgetTester tester) =>
    containerOf(tester).read(mockClosetBackendProvider);

ProviderContainer appContainer(WidgetTester tester) => containerOf(tester);

/// Lets the simulated worker finish (processing + analysis) and the screens refresh.
Future<void> settleCloset(WidgetTester tester, {int seconds = 8}) async {
  for (var i = 0; i < seconds; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await tester.pumpAndSettle();
}

/// A finished-onboarding device with the closet on screen.
Future<Harness> openCloset(WidgetTester tester, {Harness? harness}) async {
  final h = harness ?? Harness();
  h.imageProcessor = const InlineImageProcessor();
  await h.seedFinishedOnboarding();
  useTallScreen(tester);
  await h.pumpApp(tester);
  await tester.tap(find.text('My Closet'));
  await tester.pumpAndSettle();
  return h;
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

/// Brings a lazily built list item on screen, then taps it.
Future<void> tapSemantic(WidgetTester tester, String label) async {
  final all = find.bySemanticsLabel(label);
  if (all.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      all,
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 80,
    );
  }
  await tester.ensureVisible(all.first);
  await tester.pumpAndSettle();
  await tester.tap(all.first);
  await tester.pumpAndSettle();
}

/// Scrolls the page's main list until [target] is built, then taps it.
Future<void> scrollTap(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 80,
    );
  }
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}
