import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/config/domain/remote_config.dart';
import 'package:stylist/features/onboarding/domain/onboarding_step.dart';

/// The committed OpenAPI document (docs/openapi.json, generated from FastAPI and
/// diffed in CI) is the source of truth. These checks keep the Dart client honest.
void main() {
  final spec =
      jsonDecode(File('../docs/openapi.json').readAsStringSync())
          as Map<String, dynamic>;
  final paths = spec['paths'] as Map<String, dynamic>;
  final schemas =
      (spec['components'] as Map)['schemas'] as Map<String, dynamic>;

  Set<String> props(String schema) =>
      ((schemas[schema] as Map)['properties'] as Map).keys
          .cast<String>()
          .toSet();

  test('every endpoint the app calls exists with that method', () {
    const used = {
      'GET /v1/config',
      'POST /v1/auth/session',
      'POST /v1/auth/upgrade',
      'POST /v1/auth/sign-out',
      'GET /v1/me',
      'PATCH /v1/me',
      'DELETE /v1/me',
      'POST /v1/me/restore',
      'GET /v1/onboarding',
      'PUT /v1/onboarding',
      'POST /v1/me/age-confirmation',
      'GET /v1/me/preferences',
      'PUT /v1/me/preferences',
      'GET /v1/me/consents',
      'PUT /v1/me/consents',
      'POST /v1/me/export',
      'GET /v1/me/export/{job_id}',
      'GET /v1/me/export/{job_id}/download',
      'GET /v1/places/autocomplete',
      'GET /v1/sample/closet',
    };
    for (final call in used) {
      final parts = call.split(' ');
      final path = paths[parts[1]] as Map<String, dynamic>?;
      expect(path, isNotNull, reason: '${parts[1]} missing from OpenAPI');
      expect(path!.containsKey(parts[0].toLowerCase()), isTrue, reason: call);
    }
  });

  test('AppUser only reads fields the API returns', () {
    final api = props('UserOut');
    final client = const AppUser(
      id: 'x',
      isAnonymous: true,
    ).toJson().keys.toSet();
    expect(
      api.containsAll(client),
      isTrue,
      reason: 'client-only fields: ${client.difference(api)}',
    );
  });

  test('UserPatch sends only fields PATCH /v1/me accepts', () {
    const patch = UserPatch(
      displayName: 'a',
      units: Units.metric,
      city: 'c',
      clothingDepartment: ClothingDepartment.both,
      dailyOutfitTime: '08:00',
    );
    expect(props('UserPatch').containsAll(patch.toJson().keys), isTrue);
  });

  test('config flags and onboarding steps match the server contract', () {
    final cfg = props('ConfigResponse');
    expect(
      cfg,
      containsAll([
        'flags',
        'policy_version',
        'privacy_policy_url',
        'terms_url',
        'min_age',
      ]),
    );
    final parsed = RemoteConfig.fromApi({
      'flags': {
        'guest_mode_enabled': false,
        'onboarding_variant': 'closet_first',
      },
      'policy_version': 'v9',
      'privacy_policy_url': 'p',
      'terms_url': 't',
      'min_age': 16,
    });
    expect(parsed.guestModeEnabled, isFalse);
    expect(parsed.onboardingVariant, OnboardingVariant.closetFirst);
    // Unknown / invalid values fall back to defaults instead of crashing.
    expect(
      RemoteConfig.fromApi({
        'flags': {'onboarding_variant': 'weird'},
      }).onboardingVariant,
      OnboardingVariant.quizFirst,
    );

    final stepEnum =
        ((schemas['OnboardingOut'] as Map)['properties'] as Map)['current_step']
            as Map;
    final serverSteps = (stepEnum['enum'] as List).cast<String>().toSet();
    expect(OnboardingStep.values.map((s) => s.wire).toSet(), serverSteps);
  });

  test('preference answers use the same enums as the server model', () {
    final text = File('../api/app/domain/preferences.py').readAsStringSync();
    for (final word in [
      'relaxed',
      'regular',
      'slim',
      'menswear',
      'womenswear',
      'everything',
      'bright_colors',
      'crop_tops',
    ]) {
      expect(text, contains('"$word"'), reason: word);
    }
  });
}
