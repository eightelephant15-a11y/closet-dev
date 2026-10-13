import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// iOS permission explanations are generated from the ARB (tool/gen_ios_strings.py).
void main() {
  final arb =
      jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, dynamic>;
  final strings = File(
    'ios/Runner/en.lproj/InfoPlist.strings',
  ).readAsStringSync();

  const keys = {
    'NSCameraUsageDescription': 'iosCameraUsage',
    'NSPhotoLibraryUsageDescription': 'iosPhotoLibraryUsage',
    'NSLocationWhenInUseUsageDescription': 'iosLocationUsage',
  };

  for (final e in keys.entries) {
    test('${e.key} matches ARB ${e.value}', () {
      expect(
        strings,
        contains('"${e.key}" = "${arb[e.value]}";'),
        reason: 'run: python3 tool/gen_ios_strings.py',
      );
    });
  }

  test('Info.plist declares every usage description the app can trigger', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    for (final k in keys.keys) {
      expect(plist, contains('<key>$k</key>'));
    }
  });

  test(
    'every flavor has an xcconfig, an app icon set and a Firebase plist slot',
    () {
      for (final f in ['dev', 'staging', 'prod']) {
        expect(
          File('ios/Flutter/flavors/$f.xcconfig').existsSync(),
          isTrue,
          reason: f,
        );
        for (final m in ['Debug', 'Release', 'Profile']) {
          expect(
            File('ios/Flutter/$m-$f.xcconfig').existsSync(),
            isTrue,
            reason: '$m-$f',
          );
        }
        expect(
          File(
            'ios/Runner.xcodeproj/xcshareddata/xcschemes/$f.xcscheme',
          ).existsSync(),
          isTrue,
        );
        expect(
          File('ios/config/$f/GoogleService-Info.plist.example').existsSync(),
          isTrue,
        );
        final icon = f == 'prod' ? 'AppIcon' : 'AppIcon-$f';
        expect(
          Directory('ios/Runner/Assets.xcassets/$icon.appiconset').existsSync(),
          isTrue,
        );
      }
    },
  );

  test(
    'flavor identities are distinct and follow the placeholder bundle ID',
    () {
      String read(String f, String key) =>
          RegExp('^$key = (.*)\$', multiLine: true)
              .firstMatch(
                File('ios/Flutter/flavors/$f.xcconfig').readAsStringSync(),
              )!
              .group(1)!
              .trim();
      expect(read('prod', 'APP_BUNDLE_ID'), 'com.example.stylist');
      expect(read('dev', 'APP_BUNDLE_ID'), 'com.example.stylist.dev');
      expect(read('staging', 'APP_BUNDLE_ID'), 'com.example.stylist.staging');
      final schemes = [
        'dev',
        'staging',
        'prod',
      ].map((f) => read(f, 'DEEP_LINK_SCHEME')).toSet();
      expect(schemes, hasLength(3));
    },
  );
}
