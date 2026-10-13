import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/auth/application/session_controller.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';
import 'package:stylist/features/onboarding/domain/onboarding_step.dart';

/// Entry points used by the UI: sign-in and guest start, with analytics and
/// onboarding start. UI code never talks to the auth provider directly, so
/// adding Apple / email link only changes this file and the auth providers.
class AuthFlow {
  AuthFlow(this._ref);
  final Ref _ref;

  /// Signing in (or starting as guest) is the end of the welcome step.
  Future<void> _enterOnboarding() async {
    final ctl = _ref.read(onboardingControllerProvider.notifier);
    await ctl.startOrResume();
    final s = _ref.read(onboardingControllerProvider);
    if (s != null && !s.completed.contains(OnboardingStep.welcome)) {
      ctl.completeStep(OnboardingStep.welcome);
    }
  }

  Future<void> startGuest() async {
    _ref.read(analyticsServiceProvider).track(AnalyticsEvent.guestStarted);
    await _ref.read(sessionControllerProvider.notifier).continueAsGuest();
    await _enterOnboarding();
  }

  Future<void> signInWithGoogle() async {
    final analytics = _ref.read(analyticsServiceProvider)
      ..track(AnalyticsEvent.signinStarted, {'method': 'google'});
    await _ref.read(sessionControllerProvider.notifier).signInWithGoogle();
    analytics.track(AnalyticsEvent.signinCompleted, {'method': 'google'});
    await _enterOnboarding();
  }

  /// Guest -> Google account, keeping all data. Returns normally on success.
  Future<void> upgradeGuest() async {
    final analytics = _ref.read(analyticsServiceProvider)
      ..track(AnalyticsEvent.signinStarted, {
        'method': 'google',
        'upgrade': true,
      });
    await _ref.read(sessionControllerProvider.notifier).upgradeGuest();
    analytics.track(AnalyticsEvent.signinCompleted, {
      'method': 'google',
      'upgrade': true,
    });
  }
}

final authFlowProvider = Provider<AuthFlow>(AuthFlow.new);
