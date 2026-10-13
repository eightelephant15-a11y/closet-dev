import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/features/auth/application/session_controller.dart';
import 'package:stylist/features/consent/application/consent_controller.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';

/// App start-up: restore session and onboarding progress (resume after kill).
final bootProvider = FutureProvider<void>((ref) async {
  // Riverpod forbids mutating other providers synchronously during init.
  await Future<void>.value();
  final session = ref.read(sessionControllerProvider.notifier);
  final onboarding = ref.read(onboardingControllerProvider.notifier)
    ..loadLocal();
  final consent = ref.read(consentControllerProvider.notifier)
    ..applyToAnalytics();
  await session.init();
  if (onboarding.isBlocked) {
    await onboarding.retryBlockedPurge();
    return;
  }
  if (ref.read(sessionControllerProvider).isSignedIn) {
    await consent.syncFromServer();
    await onboarding.startOrResume();
  }
});
