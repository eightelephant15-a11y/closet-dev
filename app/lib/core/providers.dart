import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stylist/core/analytics/analytics_service.dart';
import 'package:stylist/core/app_config.dart';
import 'package:stylist/core/network/api_client.dart';
import 'package:stylist/core/storage/key_value_store.dart';
import 'package:stylist/core/sync/outbox.dart';
import 'package:stylist/features/auth/application/session_controller.dart';
import 'package:stylist/features/auth/data/account_repositories.dart';
import 'package:stylist/features/auth/data/fake_auth_provider.dart';
import 'package:stylist/features/auth/data/firebase_auth_provider.dart';
import 'package:stylist/features/auth/domain/account_repository.dart';
import 'package:stylist/features/auth/domain/auth_provider.dart';
import 'package:stylist/features/config/data/config_repositories.dart';
import 'package:stylist/features/config/domain/remote_config.dart';
import 'package:stylist/features/onboarding/application/outbox_executor.dart';
import 'package:stylist/features/onboarding/data/onboarding_repositories.dart';
import 'package:stylist/features/onboarding/domain/onboarding_repository.dart';
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

/// Gated analytics: events are buffered until the consent decision is known.
final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => NoopAnalytics(),
);

final outboxProvider = Provider<Outbox>((ref) {
  return Outbox(
    ref.watch(keyValueStoreProvider),
    (op) => executeOutboxOp(ref, op),
  );
});
