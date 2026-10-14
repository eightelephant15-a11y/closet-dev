import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stylist/features/closet/application/closet_providers.dart';
import 'package:stylist/features/closet/presentation/closet_routes.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

/// Friendly stop when the free closet limit is reached. Payments arrive in Phase 6; until then this is
/// an explanation plus a way to make room (archive or delete).
class UpgradeScreen extends ConsumerWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final limit = ref.watch(closetSummaryProvider).valueOrNull?.limit ?? 30;
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
        child: CenteredScroll(
          children: [
            const ExcludeSemantics(child: Icon(Icons.checkroom, size: 64)),
            const SizedBox(height: Spacing.md),
            Text(
              l10n.upgradeTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.sm),
            Text(l10n.upgradeBody(limit), textAlign: TextAlign.center),
            const SizedBox(height: Spacing.lg),
            FilledButton(
              onPressed: () => context.go(ClosetRoutes.root),
              child: Text(l10n.upgradeCta),
            ),
          ],
        ),
      ),
    );
  }
}
