import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/core/storage/key_value_store.dart';
import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/closet/data/blob_store.dart';
import 'package:stylist/features/closet/data/mock_closet.dart';
import 'package:stylist/features/closet/domain/closet_query.dart';
import 'package:stylist/features/closet/domain/garment.dart';
import 'package:stylist/features/closet/domain/garment_repository.dart';
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
      'GET /v1/entitlements',
      'GET /v1/garments',
      'POST /v1/garments',
      'POST /v1/garments/bulk',
      'GET /v1/garments/summary',
      'POST /v1/garments/sample',
      'GET /v1/garments/{garment_id}',
      'PATCH /v1/garments/{garment_id}',
      'DELETE /v1/garments/{garment_id}',
      'POST /v1/garments/{garment_id}/reanalyse',
      'POST /v1/garments/{garment_id}/images/{image_id}/upload-url',
      'POST /v1/garments/{garment_id}/images/{image_id}/complete',
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

  group('closet', () {
    Set<String> required(String schema) =>
        ((schemas[schema] as Map)['required'] as List).cast<String>().toSet();

    test('the mock closet returns the same fields as the API', () async {
      final backend = MockClosetBackend(
        store: MemoryKeyValueStore(),
        blobs: MemoryBlobStore(),
        userKey: 'u',
        itemLimit: () => 30,
        processingDelay: Duration.zero,
        analysisDelay: Duration.zero,
      );
      final created = await backend.create(
        const NewGarment(clientId: 'c1', contentType: 'image/jpeg'),
      );
      final json = backend.rawJson(created.garment.id);
      expect(json.keys.toSet(), containsAll(required('GarmentOut')));
      expect(
        props('GarmentOut'),
        containsAll(json.keys),
        reason:
            'mock-only fields: ${json.keys.toSet().difference(props('GarmentOut'))}',
      );
      final analysis = (json['analysis'] as Map).keys.toSet();
      expect(props('AnalysisOut'), containsAll(analysis));
      final ticket = created.ticket!;
      expect(ticket.imageId, isNotEmpty);
      // The same document parses back into the app model without loss.
      expect(Garment.fromApi(json).id, created.garment.id);
    });

    test(
      'summary, entitlements, ticket and list item fields exist server side',
      () {
        final summary = props('ClosetSummary');
        expect(
          summary,
          containsAll([
            'total',
            'archived',
            'favorites',
            'needs_review',
            'counts',
            'available_counts',
            'closet_item_limit',
            'closet_items_used',
          ]),
        );
        expect(
          props('EntitlementsOut'),
          containsAll(['closet_item_limit', 'closet_items_used', 'plan']),
        );
        expect(
          props('UploadTicketOut'),
          containsAll([
            'image_id',
            'url',
            'method',
            'headers',
            'fields',
            'expires_at',
            'max_bytes',
          ]),
        );
        expect(
          props('GarmentListItem'),
          containsAll([
            'analysis_status',
            'thumb_url',
            'image_version',
            'low_confidence_fields',
          ]),
        );
        expect(
          props('GarmentPage'),
          containsAll(['items', 'total', 'next_cursor']),
        );
      },
    );

    test('query parameters are ones GET /v1/garments accepts', () {
      final accepted =
          ((paths['/v1/garments'] as Map)['get'] as Map)['parameters'] as List;
      final names = {for (final p in accepted) (p as Map)['name'] as String};
      const query = ClosetQuery(
        category: 'top',
        subcategory: 'shirt',
        color: 'navy',
        season: 'winter',
        formalityMin: 2,
        formalityMax: 4,
        text: 'x',
        favorite: true,
        availability: 'laundry',
        reviewed: false,
      );
      expect(names, containsAll(query.toParams(cursor: 'c').keys));
    });

    test('patch fields are ones PATCH /v1/garments/{id} accepts', () {
      const sent = [
        'category',
        'subcategory',
        'primary_color',
        'secondary_color',
        'pattern',
        'formality',
        'seasons',
        'fit',
        'material',
        'brand',
        'notes',
        'favorite',
        'availability',
        'unavailable_until',
        'archived',
        'reviewed',
      ];
      expect(props('GarmentPatch'), containsAll(sent));
    });

    test('taxonomy version matches the server', () {
      final text = File(
        '../taxonomy/garment_taxonomy.v1.json',
      ).readAsStringSync();
      expect((jsonDecode(text) as Map)['version'], 1);
    });
  });
}
