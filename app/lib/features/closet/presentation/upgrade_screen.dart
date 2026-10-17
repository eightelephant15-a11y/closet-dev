import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stylist/features/closet/application/closet_providers.dart';
import 'package:stylist/features/closet/domain/closet_query.dart';
import 'package:stylist/features/closet/presentation/closet_routes.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/atelier.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

/// Friendly stop when the free closet limit is reached. Payments arrive in a later phase; until then this
/// is an explanation plus ways to make room (archive or delete).
class UpgradeScreen extends ConsumerWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final summary = ref.watch(closetSummaryProvider).valueOrNull;
    final limit = summary?.limit ?? 30;
    final used = summary?.used ?? limit;
    final archived = summary?.archived ?? 0;
    final review = summary?.needsReview ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.upgradeTitle),
        leading: IconButton(
          tooltip: l10n.close,
          icon: const Icon(Icons.close),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(ClosetRoutes.root),
        ),
      ),
      body: PageBody(
        child: ListView(
          children: [
            Center(
              child: BadgeIcon(icon: Icons.checkroom, pill: '$used/$limit'),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              l10n.upgradeTitle,
              style: text.headlineLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              l10n.upgradeBody(limit),
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.lg),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(RadiusTokens.lg),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: Spacing.md,
                    children: [
                      Text(l10n.limitCapacity, style: text.titleMedium),
                      Text(
                        l10n.closetCount(used, limit),
                        style: text.labelLarge?.copyWith(color: scheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.sm),
                  ExcludeSemantics(
                    child: LinearProgressIndicator(
                      value: limit == 0 ? 1 : (used / limit).clamp(0, 1),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(RadiusTokens.lg),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(l10n.limitTipsTitle),
                  const SizedBox(height: Spacing.sm),
                  _Tip(
                    icon: Icons.archive_outlined,
                    title: l10n.limitTipArchiveTitle,
                    body: l10n.limitTipArchiveBody,
                  ),
                  if (review > 0) ...[
                    Divider(height: Spacing.lg, color: scheme.outlineVariant),
                    _Tip(
                      icon: Icons.flag_outlined,
                      title: l10n.limitTipReviewTitle,
                      body: l10n.limitTipReviewBody(review),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () => context.go(ClosetRoutes.root),
                icon: const Icon(Icons.tune),
                label: Text(l10n.upgradeCta),
              ),
            ),
            if (archived > 0) ...[
              const SizedBox(height: Spacing.sm),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: scheme.surfaceContainerLowest,
                  foregroundColor: scheme.onSurface,
                ),
                onPressed: () {
                  ref.read(closetQueryProvider.notifier).state =
                      const ClosetQuery(archived: ArchivedMode.only);
                  context.go(ClosetRoutes.root);
                },
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(l10n.limitViewArchived(archived)),
              ),
            ],
            const SizedBox(height: Spacing.lg),
          ],
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(RadiusTokens.md),
            ),
            child: Icon(icon, color: scheme.primary, size: 22),
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleMedium),
              Text(
                body,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
