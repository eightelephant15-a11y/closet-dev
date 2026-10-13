import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/features/closet/domain/unlock_rule.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

/// "Add your first 10 items" shell. Real capture/upload is Phase 2: the sample
/// closet shortcut stands in for it.
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final p = _progress;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.firstItemsTitle),
        automaticallyImplyLeading: false,
      ),
      body: PageBody(
        child: _failed
            ? ErrorView(message: l10n.errorGeneric, onRetry: _load)
            : p == null
            ? const LoadingView()
            : ListView(
                children: [
                  Text(l10n.firstItemsBody, style: textTheme.bodyLarge),
                  const SizedBox(height: Spacing.lg),
                  Center(child: _ProgressRing(progress: p)),
                  const SizedBox(height: Spacing.lg),
                  Text(l10n.unlockRuleTitle, style: textTheme.titleLarge),
                  const SizedBox(height: Spacing.sm),
                  _Rule(
                    label: l10n.ruleTops(p.tops.clamp(0, 2)),
                    done: p.tops >= 2,
                  ),
                  _Rule(
                    label: l10n.ruleBottoms(p.bottoms.clamp(0, 2)),
                    done: p.bottoms >= 2,
                  ),
                  _Rule(
                    label: l10n.ruleShoes(p.shoes.clamp(0, 1)),
                    done: p.shoes >= 1,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                    child: Text(l10n.unlockRuleOr, style: textTheme.labelLarge),
                  ),
                  _Rule(
                    label: l10n.ruleDress(p.dresses.clamp(0, 1)),
                    done: p.dresses >= 1,
                  ),
                  _Rule(
                    label: l10n.ruleShoes(p.shoes.clamp(0, 1)),
                    done: p.shoes >= 1,
                  ),
                  const SizedBox(height: Spacing.lg),
                  if (p.isUnlocked)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        l10n.firstItemsUnlocked,
                        style: textTheme.titleMedium,
                      ),
                    )
                  else
                    Text(l10n.firstItemsHint),
                  const SizedBox(height: Spacing.md),
                  if (!p.isUnlocked)
                    FilledButton(
                      onPressed: _busy ? null : () => _load(useSample: true),
                      child: Text(l10n.useSampleCloset),
                    ),
                  const SizedBox(height: Spacing.sm),
                  OutlinedButton(
                    onPressed: null,
                    child: Text(l10n.addWithCamera),
                  ),
                  const SizedBox(height: Spacing.sm),
                  FilledButton(
                    onPressed: p.isUnlocked
                        ? ref
                              .read(onboardingControllerProvider.notifier)
                              .completeFirstItems
                        : null,
                    child: Text(l10n.seeFirstOutfit),
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
    final label = l10n.firstItemsProgress(
      progress.total.clamp(0, firstItemsTarget),
      firstItemsTarget,
    );
    return Semantics(
      label: label,
      value: '${(progress.ringProgress * 100).round()}%',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress.ringProgress),
                  duration: MotionTokens.slow,
                  curve: MotionTokens.curve,
                  builder: (_, v, _) =>
                      CircularProgressIndicator(value: v, strokeWidth: 10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.label, required this.done});
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? scheme.primary : scheme.outline,
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
