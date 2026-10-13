import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';
import 'package:stylist/features/onboarding/domain/onboarding_state.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/l10n/labels.dart';
import 'package:stylist/theme/tokens.dart';

IconData permissionIcon(PermissionKind k) => switch (k) {
  PermissionKind.camera => Icons.photo_camera_outlined,
  PermissionKind.photos => Icons.photo_library_outlined,
  PermissionKind.location => Icons.location_on_outlined,
  PermissionKind.notifications => Icons.notifications_outlined,
};

/// In-context priming: one line of "why", then the OS prompt only if the user
/// agrees. Denial never blocks: it shows a working fallback and moves on.
class PermissionPrimer extends ConsumerStatefulWidget {
  const PermissionPrimer({required this.kind, required this.onDone, super.key});

  final PermissionKind kind;

  /// Called when the user taps Continue (after allowing, denying or skipping).
  final VoidCallback onDone;

  @override
  ConsumerState<PermissionPrimer> createState() => _PermissionPrimerState();
}

class _PermissionPrimerState extends ConsumerState<PermissionPrimer> {
  PermissionOutcome? _outcome;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(onboardingControllerProvider.notifier)
            .permissionPromptShown(widget.kind);
      }
    });
  }

  Future<void> _allow() async {
    setState(() => _busy = true);
    final outcome = await ref
        .read(permissionsServiceProvider)
        .request(widget.kind);
    ref
        .read(onboardingControllerProvider.notifier)
        .recordPermission(widget.kind, outcome);
    if (mounted) {
      setState(() {
        _outcome = outcome;
        _busy = false;
      });
    }
  }

  void _skip() {
    ref
        .read(onboardingControllerProvider.notifier)
        .recordPermission(widget.kind, PermissionOutcome.skipped);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final denied = _outcome == PermissionOutcome.denied;
    return ListView(
      shrinkWrap: true,
      children: [
        ExcludeSemantics(
          child: Icon(
            permissionIcon(widget.kind),
            size: 72,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: Spacing.lg),
        Semantics(
          header: true,
          child: Text(
            l10n.permTitle(widget.kind),
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: Spacing.md),
        Text(
          l10n.permBody(widget.kind),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: Spacing.xl),
        if (_outcome == null) ...[
          FilledButton(
            onPressed: _busy ? null : _allow,
            child: Text(l10n.permAllow),
          ),
          const SizedBox(height: Spacing.sm),
          TextButton(
            onPressed: _busy ? null : _skip,
            child: Text(l10n.permNotNow),
          ),
        ] else ...[
          Semantics(
            liveRegion: true,
            child: Text(
              denied ? l10n.permDenied(widget.kind) : l10n.permGranted,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: Spacing.lg),
          FilledButton(
            onPressed: widget.onDone,
            child: Text(l10n.continueLabel),
          ),
          if (denied) ...[
            const SizedBox(height: Spacing.sm),
            TextButton(
              onPressed: () =>
                  ref.read(permissionsServiceProvider).openSettings(),
              child: Text(l10n.permOpenSettings),
            ),
          ],
        ],
      ],
    );
  }
}
