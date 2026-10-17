import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stylist/features/closet/application/closet_providers.dart';
import 'package:stylist/features/closet/domain/unlock_rule.dart';
import 'package:stylist/features/closet/presentation/closet_routes.dart';
import 'package:stylist/features/closet/presentation/closet_widgets.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/atelier.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

/// "Add your first 10 items": drives the real closet flow (camera, library, upload queue, AI review).
/// "Use sample closet" seeds the bundled sample garments instead of uploading anything.
class FirstItemsScreen extends ConsumerStatefulWidget {
  const FirstItemsScreen({super.key});

  @override
  ConsumerState<FirstItemsScreen> createState() => _FirstItemsScreenState();
}

class _FirstItemsScreenState extends ConsumerState<FirstItemsScreen> {
  UnlockProgress? _progress;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool useSample = false}) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final ctl = ref.read(onboardingControllerProvider.notifier);
      final p = useSample
          ? await ctl.useSampleCloset()
          : await ctl.refreshFirstItems();
      if (mounted) setState(() => _progress = p);
    } on Object {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Opens the real capture flow, then re-counts what the closet now holds.
  Future<void> _open(String route) async {
    await context.push<void>(route);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final p = _progress;
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
    return Scaffold(
      body: PageBody(
        child: _failed
            ? ErrorView(message: l10n.errorGeneric, onRetry: _load)
            : p == null
            ? const LoadingView()
            : ListView(
                children: [
                  Eyebrow(l10n.firstItemsEyebrow, align: TextAlign.center),
                  const SizedBox(height: Spacing.xs),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.firstItemsTitle,
                      textAlign: TextAlign.center,
                      style: text.headlineLarge,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    l10n.firstItemsBody,
                    textAlign: TextAlign.center,
                    style: text.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  Center(child: _ProgressRing(progress: p)),
                  const SizedBox(height: Spacing.md),
                  Semantics(
                    liveRegion: true,
                    child: NoteCard(
                      icon: p.isUnlocked
                          ? Icons.check_circle_outline
                          : Icons.auto_awesome_outlined,
                      child: Text(
                        p.isUnlocked
                            ? l10n.firstItemsUnlocked
                            : l10n.firstItemsAway(p.itemsAway),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  Semantics(
                    header: true,
                    child: Text(l10n.unlockRuleTitle, style: text.titleLarge),
                  ),
                  const SizedBox(height: Spacing.sm),
                  _Rule(
                    icon: Icons.checkroom_outlined,
                    title: l10n.ruleTitleTops,
                    have: p.tops,
                    need: 2,
                  ),
                  _Rule(
                    icon: Icons.straighten_outlined,
                    title: l10n.ruleTitleBottoms,
                    have: p.bottoms,
                    need: 2,
                  ),
                  _Rule(
                    icon: Icons.hiking_outlined,
                    title: l10n.ruleTitleShoes,
                    have: p.shoes,
                    need: 1,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                    child: Center(
                      child: Eyebrow(
                        l10n.unlockRuleOr,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _Rule(
                    icon: Icons.dry_cleaning_outlined,
                    title: l10n.ruleTitleDress,
                    have: p.dresses,
                    need: 1,
                  ),
                  _Rule(
                    icon: Icons.hiking_outlined,
                    title: l10n.ruleTitleShoes,
                    have: p.shoes,
                    need: 1,
                  ),
                  const SizedBox(height: Spacing.lg),
                  if (!p.isUnlocked) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.surfaceContainerHigh,
                          foregroundColor: scheme.onSurface,
                        ),
                        onPressed: _busy ? null : () => _load(useSample: true),
                        child: Text(l10n.useSampleCloset),
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                  ],
                  pair(
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () => _open(ClosetRoutes.add),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(l10n.addWithCamera),
                      ),
                    ),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: scheme.surfaceContainerLowest,
                          foregroundColor: scheme.onSurface,
                        ),
                        onPressed: () => _open(ClosetRoutes.addFromLibrary),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(l10n.firstItemsAddPhotos),
                      ),
                    ),
                  ),
                  if (ref
                          .watch(uploadItemsProvider)
                          .valueOrNull
                          ?.any((i) => i.isActive) ??
                      false)
                    const Padding(
                      padding: EdgeInsets.only(top: Spacing.sm),
                      child: UploadBanner(),
                    ),
                  const SizedBox(height: Spacing.md),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: p.isUnlocked
                          ? ref
                                .read(onboardingControllerProvider.notifier)
                                .completeFirstItems
                          : null,
                      icon: Icon(
                        p.isUnlocked ? Icons.arrow_forward : Icons.lock_outline,
                        size: 20,
                      ),
                      label: Text(l10n.seeFirstOutfit),
                    ),
                  ),
                  if (!p.isUnlocked)
                    Padding(
                      padding: const EdgeInsets.only(top: Spacing.xs),
                      child: Text(
                        l10n.firstItemsLocked,
                        textAlign: TextAlign.center,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.progress});
  final UnlockProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final label = l10n.firstItemsProgress(
      progress.total.clamp(0, firstItemsTarget),
      firstItemsTarget,
    );
    return Semantics(
      label: label,
      value: '${(progress.ringProgress * 100).round()}%',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 168,
          height: 168,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress.ringProgress),
                  duration: MotionTokens.slow,
                  curve: MotionTokens.curve,
                  builder: (_, v, _) => CircularProgressIndicator(
                    value: v,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: scheme.surfaceContainerHigh,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line of the unlock checklist: icon, name and a "2 of 2 added" pill (green when done).
class _Rule extends StatelessWidget {
  const _Rule({
    required this.icon,
    required this.title,
    required this.have,
    required this.need,
  });
  final IconData icon;
  final String title;
  final int have;
  final int need;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final done = have >= need;
    final count = l10n.ruleCount(have.clamp(0, need), need);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Semantics(
        container: true,
        label: l10n.ruleRowLabel(title, count),
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm + 4,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(RadiusTokens.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: Spacing.sm + 4),
              Expanded(child: Text(title, style: text.titleMedium)),
              const SizedBox(width: Spacing.sm),
              Flexible(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: done
                        ? scheme.secondaryContainer
                        : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(RadiusTokens.pill),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm + 4,
                      vertical: Spacing.xs + 1,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (done) ...[
                          Icon(
                            Icons.check,
                            size: 14,
                            color: scheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: Spacing.xs),
                        ],
                        Flexible(
                          child: Text(
                            count,
                            style: text.labelMedium?.copyWith(
                              color: done
                                  ? scheme.onSecondaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
