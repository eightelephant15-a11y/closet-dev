import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stylist/app.dart';
import 'package:stylist/core/analytics/analytics_service.dart';
import 'package:stylist/core/app_config.dart';
import 'package:stylist/core/permissions/permissions_service.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/core/storage/key_value_store.dart';
import 'package:stylist/core/sync/sync_triggers.dart';
import 'package:stylist/features/auth/data/account_repositories.dart';
import 'package:stylist/features/auth/data/fake_auth_provider.dart';
import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/closet/application/closet_providers.dart';
import 'package:stylist/features/closet/application/image_pipeline.dart';
import 'package:stylist/features/closet/application/image_source.dart';
import 'package:stylist/features/closet/data/blob_store.dart';
import 'package:stylist/features/config/data/config_repositories.dart';
import 'package:stylist/features/config/domain/remote_config.dart';
import 'package:stylist/features/consent/application/consent_controller.dart';
import 'package:stylist/features/consent/data/consent_repositories.dart';
import 'package:stylist/features/data_rights/data_rights.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';
import 'package:stylist/features/onboarding/data/onboarding_repositories.dart';
import 'package:stylist/features/onboarding/domain/onboarding_repository.dart';
import 'package:stylist/features/onboarding/domain/onboarding_state.dart';
import 'package:stylist/features/onboarding/domain/onboarding_step.dart';

/// Wires the app against fakes. `store` is this "device's" disk; `serverStore`
/// is the shared mock backend (defaults to `store`). Build a second Harness on
/// the same `store` to simulate killing and restarting the app, or on a fresh
/// `store` with the same `serverStore` to simulate a second device.
class Harness {
  Harness({
    FakeAuthProvider? auth,
    RemoteConfig config = const RemoteConfig(),
    KeyValueStore? store,
    KeyValueStore? serverStore,
    RecordingAnalytics? analytics,

    /// Pre-seeded analytics decision. null leaves it undecided (consent prompt shows).
    bool? analyticsConsent = true,
  }) : store = store ?? MemoryKeyValueStore(),
       analytics = analytics ?? RecordingAnalytics() {
    final server = serverStore ?? this.store;
    this.auth = auth ?? FakeAuthProvider(store: this.store);
    accounts = MockAccountRepository(this.auth, server);
    configRepo = MockConfigRepository(config);
    onboarding = MockOnboardingRepository(
      this.auth,
      server,
      () => configRepo.config.onboardingVariant,
    );
    consents = MockConsentRepository(this.auth, server);
    exports = MockExportRepository(this.auth, server);
    if (analyticsConsent != null &&
        this.store.read(ConsentController.storeKey) == null) {
      unawaited(
        this.store.write(
          ConsentController.storeKey,
          jsonEncode({
            'analytics_opt_in': analyticsConsent,
            'no_ai_training': true,
          }),
        ),
      );
    }
  }

  final KeyValueStore store;
  final RecordingAnalytics analytics;
  late final FakeAuthProvider auth;
  late final MockAccountRepository accounts;
  late final MockConfigRepository configRepo;
  late final MockOnboardingRepository onboarding;
  late final MockConsentRepository consents;
  late final MockExportRepository exports;
  final FakePermissionsService permissions = FakePermissionsService();

  /// Closet: pictures, the camera and the library are fakes; the upload queue, mock server and image
  /// cache live in memory (use [closetServerBlobs] to share "server storage" between harnesses).
  final MemoryBlobStore queueBlobs = MemoryBlobStore();
  final MemoryBlobStore closetServerBlobs = MemoryBlobStore();
  final MemoryBlobStore imageCache = MemoryBlobStore();
  late final FakeImageSource imageSource = FakeImageSource();
  FakeCameraService camera = FakeCameraService(
    photos: [PickedImage(name: 'navy_jeans_f2.jpg', bytes: _defaultJpeg())],
  );
  ImageProcessor imageProcessor = const DartImageProcessor();
  final FakeFileSharer sharer = FakeFileSharer();
  final FakeUrlOpener urls = FakeUrlOpener();

  /// Fire to simulate the network coming back.
  final StreamController<void> connectivity =
      StreamController<void>.broadcast();

  List<Override> get overrides => [
    appConfigProvider.overrideWithValue(AppConfig.forFlavor(Flavor.dev)),
    keyValueStoreProvider.overrideWithValue(store),
    authProviderProvider.overrideWithValue(auth),
    accountRepositoryProvider.overrideWithValue(accounts),
    configRepositoryProvider.overrideWithValue(configRepo),
    onboardingRepositoryProvider.overrideWithValue(
      onboarding as OnboardingRepository,
    ),
    consentRepositoryProvider.overrideWithValue(consents),
    exportRepositoryProvider.overrideWithValue(exports),
    analyticsBackendProvider.overrideWithValue(analytics),
    permissionsServiceProvider.overrideWithValue(permissions),
    fileSharerProvider.overrideWithValue(sharer),
    urlOpenerProvider.overrideWithValue(urls),
    connectivityChangesProvider.overrideWithValue(connectivity.stream),
    queueBlobStoreProvider.overrideWithValue(queueBlobs),
    mockServerBlobStoreProvider.overrideWithValue(closetServerBlobs),
    imageCacheStoreProvider.overrideWithValue(imageCache),
    imageSourceServiceProvider.overrideWithValue(imageSource),
    cameraFactoryProvider.overrideWithValue(() => camera),
    imageProcessorProvider.overrideWithValue(imageProcessor),
  ];

  /// Puts the device in the "finished onboarding" state without driving the UI.
  Future<void> seedFinishedOnboarding({bool guest = false}) async {
    if (guest) {
      await auth.signInAnonymously();
    } else {
      await auth.signInWithGoogle();
    }
    final user = await accounts.createSession();
    await accounts.patchMe(
      const UserPatch(displayName: 'Ada', city: 'Austin, TX'),
    );
    final state = OnboardingState.initial(
      OnboardingVariant.quizFirst,
      DateTime(2026),
    ).copyWith(current: OnboardingStep.done, completedAt: DateTime(2026, 1, 2));
    await store.write(
      OnboardingController.storeKey,
      jsonEncode(state.toJson()),
    );
    await store.write('session_user_cache', jsonEncode(user.toJson()));
  }

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

Uint8List _defaultJpeg() {
  final im = img.Image(width: 48, height: 64);
  img.fill(im, color: img.ColorRgb8(30, 70, 140));
  return Uint8List.fromList(img.encodeJpg(im));
}

/// Larger surface so screens don't need scrolling in tests.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 4200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}
