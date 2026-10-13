import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stylist/core/analytics/analytics_service.dart';
import 'package:stylist/core/analytics/posthog_analytics.dart';
import 'package:stylist/core/app_config.dart';
import 'package:stylist/core/network/api_client.dart';
import 'package:stylist/core/permissions/permissions_service.dart';
import 'package:stylist/core/storage/key_value_store.dart';
import 'package:stylist/core/sync/outbox.dart';
import 'package:stylist/features/auth/application/session_controller.dart';
import 'package:stylist/features/auth/data/account_repositories.dart';
import 'package:stylist/features/auth/data/fake_auth_provider.dart';
import 'package:stylist/features/auth/data/firebase_auth_provider.dart';
import 'package:stylist/features/auth/domain/account_repository.dart';
import 'package:stylist/features/auth/domain/auth_provider.dart';
import 'package:stylist/features/closet/data/closet_repositories.dart';
import 'package:stylist/features/closet/data/sample_closet_data.dart';
import 'package:stylist/features/closet/domain/closet_item.dart';
import 'package:stylist/features/config/data/config_repositories.dart';
import 'package:stylist/features/config/domain/remote_config.dart';
import 'package:stylist/features/consent/data/consent_repositories.dart';
import 'package:stylist/features/consent/domain/consent.dart';
import 'package:stylist/features/data_rights/data_rights.dart';
import 'package:stylist/features/onboarding/application/outbox_executor.dart';
import 'package:stylist/features/onboarding/data/onboarding_repositories.dart';
import 'package:stylist/features/onboarding/domain/onboarding_repository.dart';
import 'package:stylist/features/places/places_service.dart';
import 'package:stylist/features/recommendation/domain/recommendation.dart';
import 'package:uuid/uuid.dart';

/// Overridden in each flavor entrypoint.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden'),
);

/// Overridden at bootstrap with the real store (tests use [MemoryKeyValueStore]).
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => throw UnimplementedError('keyValueStoreProvider must be overridden'),
);

Future<KeyValueStore> openPrefsStore() async =>
    PrefsKeyValueStore(await SharedPreferences.getInstance());

final deviceIdProvider = Provider<String>((ref) {
  final store = ref.watch(keyValueStoreProvider);
  var id = store.read('device_id');
  if (id == null) {
    id = const Uuid().v4();
    unawaited(store.write('device_id', id));
  }
  return id;
});

final authProviderProvider = Provider<AuthProvider>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.useMock
      ? FakeAuthProvider(store: ref.watch(keyValueStoreProvider))
      : FirebaseAuthProvider();
});

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  return buildDio(
    baseUrl: config.apiBaseUrl,
    deviceId: ref.watch(deviceIdProvider),
    getToken: ({forceRefresh = false}) =>
        ref.read(authProviderProvider).idToken(forceRefresh: forceRefresh),
    onSessionRevoked: () =>
        ref.read(sessionControllerProvider.notifier).onRevoked(),
  );
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    return MockAccountRepository(
      ref.watch(authProviderProvider),
      ref.watch(keyValueStoreProvider),
    );
  }
  return HttpAccountRepository(
    ref.watch(dioProvider),
    deviceId: ref.watch(deviceIdProvider),
    platform: Platform.isIOS ? 'ios' : 'android',
  );
});

final configRepositoryProvider = Provider<ConfigRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.useMock
      ? MockConfigRepository()
      : HttpConfigRepository(
          ref.watch(dioProvider),
          ref.watch(keyValueStoreProvider),
        );
});

final remoteConfigProvider = FutureProvider<RemoteConfig>(
  (ref) => ref.watch(configRepositoryProvider).load(),
);

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    return MockOnboardingRepository(
      ref.watch(authProviderProvider),
      ref.watch(keyValueStoreProvider),
      () =>
          ref.read(remoteConfigProvider).valueOrNull?.onboardingVariant ??
          OnboardingVariant.quizFirst,
    );
  }
  return HttpOnboardingRepository(ref.watch(dioProvider));
});

/// The real analytics backend (PostHog when configured, otherwise a no-op).
final analyticsBackendProvider = Provider<AnalyticsService>((ref) {
  final key = ref.watch(appConfigProvider).posthogKey;
  return key.isEmpty ? NoopAnalytics() : PostHogAnalyticsService(apiKey: key);
});

/// Gate in front of the backend: events are buffered until the consent decision
/// is known; nothing is sent before opt-in.
final analyticsGateProvider = Provider<ConsentGatedAnalytics>(
  (ref) => ConsentGatedAnalytics(ref.watch(analyticsBackendProvider)),
);

/// What the app tracks through.
final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => ref.watch(analyticsGateProvider),
);

final consentRepositoryProvider = Provider<ConsentRepository>((ref) {
  return ref.watch(appConfigProvider).useMock
      ? MockConsentRepository(
          ref.watch(authProviderProvider),
          ref.watch(keyValueStoreProvider),
        )
      : HttpConsentRepository(ref.watch(dioProvider));
});

final outboxProvider = Provider<Outbox>((ref) {
  return Outbox(
    ref.watch(keyValueStoreProvider),
    (op) => executeOutboxOp(ref, op),
  );
});

final permissionsServiceProvider = Provider<PermissionsService>((ref) {
  return ref.watch(appConfigProvider).useMock
      ? FakePermissionsService()
      : DevicePermissionsService();
});

final placesServiceProvider = Provider<PlacesService>((ref) {
  return ref.watch(appConfigProvider).useMock
      ? MockPlacesService()
      : HttpPlacesService(ref.watch(dioProvider));
});

final closetRepositoryProvider = Provider<ClosetRepository>((ref) {
  final useMock = ref.watch(appConfigProvider).useMock;
  final dio = useMock ? null : ref.watch(dioProvider);
  return StubClosetRepository(
    ref.watch(keyValueStoreProvider),
    () async => dio == null ? sampleClosetItems : loadSampleFromApi(dio),
  );
});

final recommendationServiceProvider = Provider<RecommendationService>(
  (ref) => FakeRecommendationService(),
);

/// The user's closet items (Phase 1: only the sample closet shortcut adds any).
final closetItemsProvider = FutureProvider<List<ClosetItem>>(
  (ref) => ref.watch(closetRepositoryProvider).items(),
);

final exportRepositoryProvider = Provider<ExportRepository>((ref) {
  return ref.watch(appConfigProvider).useMock
      ? MockExportRepository(
          ref.watch(authProviderProvider),
          ref.watch(keyValueStoreProvider),
        )
      : HttpExportRepository(ref.watch(dioProvider));
});

final fileSharerProvider = Provider<FileSharer>((ref) => SharePlusFileSharer());

final urlOpenerProvider = Provider<UrlOpener>((ref) => DeviceUrlOpener());
