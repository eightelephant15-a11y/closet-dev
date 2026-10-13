import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/core/sync/outbox.dart';
import 'package:stylist/features/auth/domain/app_user.dart';

/// Op types understood by the outbox. Extend here when adding synced features.
abstract final class OutboxOps {
  static const onboardingPut = 'onboarding.put';
  static const ageConfirm = 'age.confirm';
  static const preferencesPut = 'preferences.put';
  static const userPatch = 'user.patch';
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
      await ref
          .read(accountRepositoryProvider)
          .patchMe(
            UserPatch(
              displayName: p['display_name'] as String?,
              units: p['units'] == null
                  ? null
                  : Units.values.byName(p['units'] as String),
              city: p['city'] as String?,
              clothingDepartment: p['clothing_department'] == null
                  ? null
                  : ClothingDepartment.values.byName(
                      p['clothing_department'] as String,
                    ),
            ),
          );
    default:
      throw StateError('Unknown outbox op ${op.type}');
  }
}
