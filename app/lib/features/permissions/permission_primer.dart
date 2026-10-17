import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';
import 'package:stylist/features/onboarding/domain/onboarding_state.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/l10n/labels.dart';
import 'package:stylist/shared/widgets/atelier.dart';
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
  const PermissionPrimer({
    required this.kind,
    required this.onDone,
    this.step,
    this.steps,
    super.key,
  });

  final PermissionKind kind;

  /// "Step 2 of 3" when the primer is part of a sequence.
  final int? step;
  final int? steps;

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
    final text = Theme.of(context).textTheme;
    final denied = _outcome == PermissionOutcome.denied;
    final big = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    Widget pair(Widget a, Widget b) => big
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              a,
              const SizedBox(height: Spacing.sm),
              b,
            ],
          )
        : Row(
            children: [
              Expanded(child: a),
              const SizedBox(width: Spacing.sm),
              Expanded(child: b),
            ],
          );
    return ListView(
      shrinkWrap: true,
      children: [
        if (widget.step != null && widget.steps != null) ...[
          Eyebrow(l10n.permStep(widget.step!, widget.steps!)),
          const SizedBox(height: Spacing.sm),
        ],
        Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(RadiusTokens.xl),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(RadiusTokens.lg),
                  ),
                  child: Icon(
                    permissionIcon(widget.kind),
                    size: 28,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),
              Semantics(
                header: true,
                child: Text(
                  l10n.permTitle(widget.kind),
                  style: text.headlineLarge,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                l10n.permBody(widget.kind),
                style: text.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.md),
              NoteCard(
                icon: Icons.shield_outlined,
                child: Text(l10n.permNote),
              ),
              const SizedBox(height: Spacing.lg),
              if (_outcome == null)
                pair(
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _busy ? null : _allow,
                      child: Text(l10n.permAllow),
                    ),
                  ),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerHigh,
                      foregroundColor: scheme.onSurface,
                    ),
                    onPressed: _busy ? null : _skip,
                    child: Text(l10n.permNotNow),
                  ),
                )
              else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: denied
                        ? scheme.surfaceContainerHigh
                        : scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(RadiusTokens.lg),
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            denied
                                ? Icons.info_outline
                                : Icons.check_circle_outline,
                            color: denied
                                ? scheme.onSurfaceVariant
                                : scheme.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(width: Spacing.sm + 4),
                        Expanded(
                          child: Text(
                            denied
                                ? l10n.permDenied(widget.kind)
                                : l10n.permGranted,
                            style: text.bodyLarge?.copyWith(
                              color: denied
                                  ? scheme.onSurface
                                  : scheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: widget.onDone,
                    child: Text(l10n.continueLabel),
                  ),
                ),
                if (denied) ...[
                  const SizedBox(height: Spacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(permissionsServiceProvider).openSettings(),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(l10n.permOpenSettings),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
