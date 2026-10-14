import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stylist/features/closet/application/image_pipeline.dart';
import 'package:stylist/features/closet/application/image_source.dart';

Uint8List flat(int w, int h, {int value = 240}) =>
    Uint8List(w * h)..fillRange(0, w * h, value);

Uint8List withBox(
  int w,
  int h, {
  required int x0,
  required int y0,
  required int x1,
  required int y1,
}) {
  final luma = flat(w, h);
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      luma[y * w + x] = 40;
    }
  }
  return luma;
}

Uint8List jpeg(int w, int h, {int? orientation, bool gps = false}) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(200, 60, 60));
  if (orientation != null) im.exif.imageIfd.orientation = orientation;
  if (gps) {
    im.exif.gpsIfd.gpsLatitude = 30.2672;
    im.exif.gpsIfd.gpsLongitude = -97.7431;
    im.exif.imageIfd.make = 'SecretPhoneMaker';
  }
  return Uint8List.fromList(img.encodeJpg(im));
}

void main() {
  group('lighting', () {
    test('mean luminance of a plane', () {
      expect(PhotoMath.meanLuminance(flat(32, 32, value: 100)), 100);
      expect(PhotoMath.meanLuminance(Uint8List(0)), 0);
    });

    test('hint thresholds', () {
      expect(LightingHint.fromLuminance(20).level, LightingLevel.tooDark);
      expect(LightingHint.fromLuminance(59.9).level, LightingLevel.tooDark);
      expect(LightingHint.fromLuminance(60).level, LightingLevel.ok);
      expect(LightingHint.fromLuminance(205).level, LightingLevel.ok);
      expect(LightingHint.fromLuminance(206).level, LightingLevel.tooBright);
    });
  });

  group('crop suggestion', () {
    test('finds a garment on a plain background, with a margin', () {
      final crop = PhotoMath.suggestCrop(
        withBox(100, 100, x0: 30, y0: 20, x1: 70, y1: 80),
        100,
        100,
      )!;
      expect(crop.left, closeTo(0.25, 0.02));
      expect(crop.right, closeTo(0.75, 0.02));
      expect(crop.top, closeTo(0.15, 0.02));
      expect(crop.bottom, closeTo(0.85, 0.02));
    });

    test('no suggestion for an empty background', () {
      expect(PhotoMath.suggestCrop(flat(80, 80), 80, 80), isNull);
    });

    test('no suggestion when the item already fills the frame', () {
      expect(
        PhotoMath.suggestCrop(
          withBox(100, 100, x0: 2, y0: 2, x1: 98, y1: 98),
          100,
          100,
        ),
        isNull,
      );
    });

    test('ignores specks too small to be a garment', () {
      expect(
        PhotoMath.suggestCrop(
          withBox(100, 100, x0: 50, y0: 50, x1: 53, y1: 53),
          100,
          100,
        ),
        isNull,
      );
    });

    test('rejects nonsense sizes', () {
      expect(PhotoMath.suggestCrop(Uint8List(4), 2, 2), isNull);
    });
  });

  group('DartImageProcessor', () {
    const processor = DartImageProcessor();

    test('shrinks to the maximum side and keeps the aspect ratio', () async {
      final out = await processor.process(
        PickedImage(name: 'big.png', bytes: jpeg(3200, 1600)),
      );
      expect(out.width, PhotoMath.maxSide);
      expect(out.height, 1024);
      expect(out.filename, 'big.jpg');
      expect(out.contentType, 'image/jpeg');
    });

    test('small photos are not enlarged', () async {
      final out = await processor.process(
        PickedImage(name: 'a.jpg', bytes: jpeg(300, 200)),
      );
      expect((out.width, out.height), (300, 200));
    });

    test(
      'applies the EXIF rotation, then drops all metadata incl. GPS',
      () async {
        final input = jpeg(400, 200, orientation: 6, gps: true);
        expect(img.decodeJpg(input)!.exif.gpsIfd.hasGPSLatitude, isTrue);
        final out = await processor.process(
          PickedImage(name: 'a.jpg', bytes: input),
        );
        expect(
          (out.width, out.height),
          (200, 400),
          reason: 'rotated to upright',
        );
        final back = img.decodeJpg(out.bytes)!;
        expect(back.exif.isEmpty, isTrue, reason: 'no EXIF left');
        expect(back.exif.gpsIfd.hasGPSLatitude, isFalse);
        expect(
          String.fromCharCodes(out.bytes).contains('SecretPhoneMaker'),
          isFalse,
        );
      },
    );

    test('crops to the suggestion', () async {
      final out = await processor.process(
        PickedImage(name: 'a.jpg', bytes: jpeg(400, 400)),
        crop: const CropRect(0.25, 0.25, 0.75, 0.5),
      );
      expect((out.width, out.height), (200, 100));
    });

    test('suggests a crop from real bytes', () async {
      final im = img.Image(width: 200, height: 200);
      img.fill(im, color: img.ColorRgb8(245, 245, 245));
      img.fillRect(
        im,
        x1: 70,
        y1: 50,
        x2: 130,
        y2: 160,
        color: img.ColorRgb8(20, 30, 90),
      );
      final crop = await processor.suggestCrop(
        PickedImage(
          name: 'a.png',
          bytes: Uint8List.fromList(img.encodePng(im)),
        ),
      );
      expect(crop, isNotNull);
      expect(crop!.area, lessThan(0.6));
    });

    test('unreadable files raise a typed error', () async {
      await expectLater(
        processor.process(
          PickedImage(
            name: 'x.jpg',
            bytes: Uint8List.fromList(List.filled(40, 3)),
          ),
        ),
        throwsA(isA<ImageProcessingException>()),
      );
    });

    test('output stays small enough for a quick upload', () async {
      final noisy = img.Image(width: 3000, height: 2000);
      for (final p in noisy) {
        p
          ..r = (p.x * 7 + p.y * 3) % 256
          ..g = (p.x * 5) % 256
          ..b = (p.y * 11) % 256;
      }
      final sw = Stopwatch()..start();
      final out = await processor.process(
        PickedImage(
          name: 'n.jpg',
          bytes: Uint8List.fromList(img.encodeJpg(noisy, quality: 92)),
        ),
      );
      sw.stop();
      expect(out.bytes.length, lessThan(2 * 1024 * 1024));
      // Dev-machine guard rail (docs/performance.md): a 6 MP photo is prepared in well under 5 s.
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });
  });
}
