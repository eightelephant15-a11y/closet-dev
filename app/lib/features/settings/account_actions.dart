import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/auth/application/session_controller.dart';
import 'package:stylist/features/closet/application/closet_providers.dart';
import 'package:stylist/features/consent/application/consent_controller.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';

final accountActionsProvider = Provider<AccountActions>(AccountActions.new);

class AccountActions {
  AccountActions(this._ref);
  final Ref _ref;

  /// Removes everything stored for the signed-in user on this device.
  Future<void> wipeLocal() async {
    await _ref.read(onboardingControllerProvider.notifier).reset();
    await wipeLocalCloset(_ref);
    await _ref.read(consentControllerProvider.notifier).clearLocal();
    _ref.read(analyticsGateProvider).clearDecision();
    _ref.invalidate(remoteConfigProvider);
  }

  Future<void> signOut() async {
    await _ref.read(sessionControllerProvider.notifier).signOut();
    await wipeLocal();
  }

  /// Deletes server-side (soft delete, purge in 30 days) and wipes this device.
  Future<DateTime> deleteAccount() async {
    final purgeAfter = await _ref
        .read(accountRepositoryProvider)
        .deleteAccount();
    _ref.read(analyticsServiceProvider).track(AnalyticsEvent.accountDeleted);
    await _ref.read(sessionControllerProvider.notifier).signOut();
    await wipeLocal();
    return purgeAfter;
  }
}
