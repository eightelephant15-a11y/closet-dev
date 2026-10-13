import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/core/sync/outbox.dart';
import 'package:stylist/features/auth/application/session_controller.dart';
import 'package:stylist/features/auth/domain/app_user.dart';

/// Op types understood by the outbox. Extend here when adding synced features.
abstract final class OutboxOps {
  static const onboardingPut = 'onboarding.put';
  static const ageConfirm = 'age.confirm';
  static const preferencesPut = 'preferences.put';
  static const userPatch = 'user.patch';
  static const consentsPut = 'consents.put';
}

Future<void> executeOutboxOp(Ref ref, OutboxOp op) async {
  final onboarding = ref.read(onboardingRepositoryProvider);
  switch (op.type) {
    case OutboxOps.onboardingPut:
      await onboarding.putState(op.payload);
    case OutboxOps.ageConfirm:
      await onboarding.confirmAge();
    case OutboxOps.preferencesPut:
      await onboarding.putPreferences(op.payload);
    case OutboxOps.userPatch:
      final p = op.payload;
      final updated = await ref
          .read(accountRepositoryProvider)
          .patchMe(
            UserPatch(
              displayName: p['display_name'] as String?,
              units: p['units'] == null
                  ? null
                  : Units.values.byName(p['units'] as String),
              city: p['city'] as String?,
              dailyOutfitTime: p['daily_outfit_time'] as String?,
              clothingDepartment: p['clothing_department'] == null
                  ? null
                  : ClothingDepartment.values.byName(
                      p['clothing_department'] as String,
                    ),
            ),
          );
      ref.read(sessionControllerProvider.notifier).updateUser(updated);
    case OutboxOps.consentsPut:
      final p = op.payload;
      await ref
          .read(consentRepositoryProvider)
          .put(
            analyticsOptIn: p['analytics_opt_in'] as bool?,
            noAiTraining: p['no_ai_training'] as bool?,
            locationExplained: p['location_explained'] as bool?,
          );
    default:
      throw StateError('Unknown outbox op ${op.type}');
  }
}
