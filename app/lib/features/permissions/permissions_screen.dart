import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';
import 'package:stylist/features/onboarding/domain/onboarding_state.dart';
import 'package:stylist/features/permissions/permission_primer.dart';
import 'package:stylist/shared/widgets/state_views.dart';

/// Primes camera, photo library and location in turn. (Notifications are
/// primed where they matter: when the user picks a daily outfit time.)
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  static const List<PermissionKind> kinds = [
    PermissionKind.camera,
    PermissionKind.photos,
    PermissionKind.location,
  ];

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  int _index = -1; // -1 while we check what is already granted

  @override
  void initState() {
    super.initState();
    unawaited(_advanceFrom(0));
  }

  /// Moves to the next primer, silently skipping permissions already granted.
  Future<void> _advanceFrom(int start) async {
    final ctl = ref.read(onboardingControllerProvider.notifier);
    final service = ref.read(permissionsServiceProvider);
    var i = start;
    while (i < PermissionsScreen.kinds.length) {
      final kind = PermissionsScreen.kinds[i];
      if (await service.isGranted(kind)) {
        ctl.recordPermission(kind, PermissionOutcome.granted);
        i++;
      } else {
        break;
      }
    }
    if (!mounted) return;
    if (i >= PermissionsScreen.kinds.length) {
      ctl.completePermissions();
    } else {
      setState(() => _index = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageBody(
        child: _index < 0
            ? const LoadingView()
            : Center(
                child: PermissionPrimer(
                  key: ValueKey(_index),
                  kind: PermissionsScreen.kinds[_index],
                  onDone: () => _advanceFrom(_index + 1),
                ),
              ),
      ),
    );
  }
}
