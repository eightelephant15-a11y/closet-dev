import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/app.dart';
import 'package:stylist/core/analytics/analytics_service.dart';
import 'package:stylist/core/app_config.dart';
import 'package:stylist/core/permissions/permissions_service.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/core/storage/key_value_store.dart';
import 'package:stylist/features/auth/data/account_repositories.dart';
import 'package:stylist/features/auth/data/fake_auth_provider.dart';
import 'package:stylist/features/config/data/config_repositories.dart';
import 'package:stylist/features/config/domain/remote_config.dart';
import 'package:stylist/features/onboarding/data/onboarding_repositories.dart';
import 'package:stylist/features/onboarding/domain/onboarding_repository.dart';

/// Wires the app against fakes, sharing one local "disk" so tests can simulate
/// killing and restarting the app by building a second Harness on the same store.
class Harness {
  Harness({
    FakeAuthProvider? auth,
    RemoteConfig config = const RemoteConfig(),
    KeyValueStore? store,
    RecordingAnalytics? analytics,
  }) : store = store ?? MemoryKeyValueStore(),
       analytics = analytics ?? RecordingAnalytics() {
    this.auth = auth ?? FakeAuthProvider(store: this.store);
    accounts = MockAccountRepository(this.auth, this.store);
    configRepo = MockConfigRepository(config);
    onboarding = MockOnboardingRepository(
      this.auth,
      this.store,
      () => configRepo.config.onboardingVariant,
    );
  }

  final KeyValueStore store;
  final RecordingAnalytics analytics;
  late final FakeAuthProvider auth;
  late final MockAccountRepository accounts;
  late final MockConfigRepository configRepo;
  late final MockOnboardingRepository onboarding;
  final FakePermissionsService permissions = FakePermissionsService();

  List<Override> get overrides => [
    appConfigProvider.overrideWithValue(AppConfig.forFlavor(Flavor.dev)),
    keyValueStoreProvider.overrideWithValue(store),
    authProviderProvider.overrideWithValue(auth),
    accountRepositoryProvider.overrideWithValue(accounts),
    configRepositoryProvider.overrideWithValue(configRepo),
    onboardingRepositoryProvider.overrideWithValue(
      onboarding as OnboardingRepository,
    ),
    analyticsServiceProvider.overrideWithValue(analytics),
    permissionsServiceProvider.overrideWithValue(permissions),
  ];

  ProviderContainer container() => ProviderContainer(overrides: overrides);

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container(),
        child: const StylistApp(),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// Larger surface so screens don't need scrolling in tests.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}
