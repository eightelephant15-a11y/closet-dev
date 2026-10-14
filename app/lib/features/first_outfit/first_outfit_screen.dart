import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/auth/application/auth_flow.dart';
import 'package:stylist/features/auth/application/session_controller.dart';
import 'package:stylist/features/auth/domain/auth_provider.dart';
import 'package:stylist/features/closet/application/closet_providers.dart';
import 'package:stylist/features/closet/domain/closet_item.dart';
import 'package:stylist/features/closet/domain/taxonomy_labels.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';
import 'package:stylist/features/onboarding/domain/onboarding_step.dart';
import 'package:stylist/features/onboarding/domain/preference_model.dart';
import 'package:stylist/features/recommendation/domain/recommendation.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/l10n/labels.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

final AutoDisposeFutureProvider<FirstOutfits?> firstOutfitsProvider =
    FutureProvider.autoDispose<FirstOutfits?>((
      ref,
    ) async {
      final answers = ref.watch(
        onboardingControllerProvider.select((s) => s!.quiz),
      );
      final closet = await ref.watch(closetItemsProvider.future);
      return ref
          .read(recommendationServiceProvider)
          .firstOutfits(
            prefs: PreferenceModel.fromAnswers(answers),
            answers: answers,
            closet: closet,
          );
    });

/// One outfit plus two alternatives, each with a "why". Powered by the
/// [RecommendationService] seam (fake in Phase 1).
class FirstOutfitScreen extends ConsumerStatefulWidget {
  const FirstOutfitScreen({super.key});

  @override
  ConsumerState<FirstOutfitScreen> createState() => _FirstOutfitScreenState();
}

class _FirstOutfitScreenState extends ConsumerState<FirstOutfitScreen> {
  final _saved = <int>{};

  Future<void> _save(int index) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final session = ref.read(sessionControllerProvider);
    if (session.status == SessionStatus.guest) {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const SaveSignInSheet(),
      );
      if (ok != true) return;
    }
    setState(() => _saved.add(index));
    messenger.showSnackBar(SnackBar(content: Text(l10n.outfitSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final outfits = ref.watch(firstOutfitsProvider);
    ref.listen(firstOutfitsProvider, (_, next) {
      if (next.valueOrNull != null) {
        ref.read(onboardingControllerProvider.notifier).firstOutfitViewed();
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.firstOutfitTitle),
        automaticallyImplyLeading: false,
      ),
      body: PageBody(
        child: outfits.when(
          loading: () => const LoadingView(),
          error: (_, _) => ErrorView(
            message: l10n.errorGeneric,
            onRetry: () => ref.invalidate(firstOutfitsProvider),
          ),
          data: (data) {
            if (data == null) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.firstOutfitEmptyTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: Spacing.sm),
                  EmptyView(message: l10n.firstOutfitEmptyBody),
                  FilledButton(
                    onPressed: () => context.go(OnboardingStep.firstItems.path),
                    child: Text(l10n.backToItems),
                  ),
                ],
              );
            }
            // Fire once the data is on screen (covers the already-cached case).
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ref
                    .read(onboardingControllerProvider.notifier)
                    .firstOutfitViewed();
              }
            });
            final all = [data.primary, ...data.alternatives];
            return ListView(
              children: [
                for (var i = 0; i < all.length; i++) ...[
                  if (i == 1)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: Spacing.md,
                        bottom: Spacing.sm,
                      ),
                      child: Semantics(
                        header: true,
                        child: Text(
                          l10n.firstOutfitAlternatives,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                  OutfitCard(
                    index: i,
                    outfit: all[i],
                    prominent: i == 0,
                    saved: _saved.contains(i),
                    onSave: () => _save(i),
                  ),
                  const SizedBox(height: Spacing.md),
                ],
                FilledButton(
                  onPressed: ref
                      .read(onboardingControllerProvider.notifier)
                      .completeFirstOutfit,
                  child: Text(l10n.continueLabel),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class OutfitCard extends StatelessWidget {
  const OutfitCard({
    required this.index,
    required this.outfit,
    required this.prominent,
    required this.saved,
    required this.onSave,
    super.key,
  });

  final int index;
  final Outfit outfit;
  final bool prominent;
  final bool saved;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: l10n.outfitLabel(index + 1),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: prominent
            ? scheme.primary.withValues(alpha: 0.08)
            : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.lg),
          side: BorderSide(
            color: prominent ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.outfitLabel(index + 1), style: textTheme.titleLarge),
              const SizedBox(height: Spacing.sm),
              for (final item in outfit.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          _icon(item.category),
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Text(
                          _itemName(l10n, item),
                          style: textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: Spacing.sm),
              Text(
                l10n.why(outfit.why),
                style: textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: saved ? null : onSave,
                  icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                  label: Text(saved ? l10n.outfitSaved : l10n.saveOutfit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _icon(ItemCategory c) => switch (c) {
    ItemCategory.top => Icons.checkroom,
    ItemCategory.bottom => Icons.straighten,
    ItemCategory.shoes => Icons.hiking,
    ItemCategory.dress => Icons.dry_cleaning,
    ItemCategory.outerwear => Icons.layers_outlined,
  };
}

/// Shown only when a guest tries to save: upgrade to a Google account without losing data.
class SaveSignInSheet extends ConsumerStatefulWidget {
  const SaveSignInSheet({super.key});

  @override
  ConsumerState<SaveSignInSheet> createState() => _SaveSignInSheetState();
}

class _SaveSignInSheetState extends ConsumerState<SaveSignInSheet> {
  bool _busy = false;

  Future<void> _upgrade() async {
    final l10n = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(authFlowProvider).upgradeGuest();
      nav.pop(true);
    } on AuthCancelled {
      if (mounted) setState(() => _busy = false);
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.signInFailed)));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.saveSignInTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Spacing.sm),
            Text(l10n.saveSignInBody),
            const SizedBox(height: Spacing.lg),
            if (_busy)
              const SizedBox(
                height: Spacing.minTouchTarget,
                child: LoadingView(),
              )
            else ...[
              FilledButton(
                onPressed: _upgrade,
                child: Text(l10n.saveSignInButton),
              ),
              const SizedBox(height: Spacing.sm),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.saveSignInLater),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _itemName(AppLocalizations l10n, ClosetItem item) {
  final sub = item.subcategory;
  final color = item.colorId;
  if (sub == null || color == null) return item.name;
  return l10n.garmentName(l10n.taxColor(color), l10n.taxSubcategory(sub));
}
