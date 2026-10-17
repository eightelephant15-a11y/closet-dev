import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stylist/features/auth/application/session_controller.dart';
import 'package:stylist/features/closet/application/closet_providers.dart';
import 'package:stylist/features/closet/domain/garment.dart';
import 'package:stylist/features/closet/presentation/closet_routes.dart';
import 'package:stylist/features/closet/presentation/closet_screen.dart';
import 'package:stylist/features/closet/presentation/closet_widgets.dart';
import 'package:stylist/features/optional/optional_screens.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/atelier.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

/// Home: a greeting, today's outfit (a placeholder until outfit suggestions exist), a live look at the
/// closet, the newest pieces, and the optional set-up steps.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final session = ref.watch(sessionControllerProvider);
    final name = session.user?.displayName;
    final hasName = name != null && name.isNotEmpty;
    final summary = ref.watch(closetSummaryProvider).valueOrNull;
    final meter = ref.watch(closetMeterProvider).valueOrNull;
    final recent = ref.watch(closetListProvider).valueOrNull?.items ?? const [];
    return Scaffold(
      body: PageBody(
        child: ListView(
          children: [
            if (session.offline) const OfflineBanner(),
            Eyebrow(l10n.brandEyebrow, color: scheme.onSurfaceVariant),
            const SizedBox(height: Spacing.xs),
            Semantics(
              header: true,
              child: Text.rich(
                TextSpan(
                  children: hasName
                      ? [
                          TextSpan(text: l10n.homeGreetingLead),
                          TextSpan(
                            text: name,
                            style: TextStyle(
                              fontFamily: TypeTokens.serif,
                              fontStyle: FontStyle.italic,
                              color: scheme.primary,
                            ),
                          ),
                        ]
                      : [TextSpan(text: l10n.homeGreetingNoName)],
                ),
                style: text.displaySmall,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              l10n.homePlaceholder,
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.lg),
            _TodayCard(onAdd: () => context.go(ClosetRoutes.root)),
            const SizedBox(height: Spacing.lg),
            _SectionHeader(
              title: l10n.homeClosetCard,
              action: l10n.homeClosetOpen,
              onAction: () => context.go(ClosetRoutes.root),
            ),
            const SizedBox(height: Spacing.sm),
            if (summary != null && meter != null)
              ClosetMeterCard(summary: summary, meter: meter)
            else
              Text(
                l10n.homeClosetCardBody,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: Spacing.lg),
              _SectionHeader(
                title: l10n.homeRecentTitle,
                action: l10n.homeViewAll,
                onAction: () => context.go(ClosetRoutes.root),
              ),
              const SizedBox(height: Spacing.sm),
              _RecentStrip(items: recent.take(8).toList()),
            ],
            const SizedBox(height: Spacing.lg),
            Semantics(
              header: true,
              child: Text(l10n.homeFinishSetup, style: text.titleLarge),
            ),
            const SizedBox(height: Spacing.sm),
            const OptionalTiles(),
            const SizedBox(height: Spacing.lg),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onAction,
  });
  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
      TextButton(onPressed: onAction, child: Text(action)),
    ],
  );
}

/// Today's outfit. Honest placeholder: outfit suggestions arrive in a later phase.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(RadiusTokens.xl),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(l10n.homeTodayTitle),
          const SizedBox(height: Spacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_awesome, color: scheme.onPrimary),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Text(
                  l10n.homeTodaySoonTitle,
                  style: text.headlineMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            l10n.homeTodaySoonBody,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Spacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onAdd,
              child: Text(l10n.homeTodayCta),
            ),
          ),
        ],
      ),
    );
  }
}

/// The newest garments as a swipeable row of portrait tiles.
class _RecentStrip extends StatelessWidget {
  const _RecentStrip({required this.items});
  final List<GarmentSummary> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      height: 170 + 56 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: Spacing.gutter),
        itemBuilder: (context, i) {
          final g = items[i];
          final name = garmentName(
            l10n,
            category: g.category,
            subcategory: g.subcategory,
            color: g.primaryColor,
          );
          void open() => context.push(ClosetRoutes.item(g.id));
          return SizedBox(
            width: 132,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    excludeFromSemantics: true,
                    borderRadius: BorderRadius.circular(RadiusTokens.lg),
                    onTap: open,
                    child: ExcludeSemantics(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(RadiusTokens.lg),
                        child: SizedBox(
                          width: double.infinity,
                          child: GarmentThumb(garment: g, cacheWidth: 400),
                        ),
                      ),
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: name,
                  excludeSemantics: true,
                  onTap: open,
                  child: InkWell(
                    excludeFromSemantics: true,
                    onTap: open,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: Spacing.minTouchTarget,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: Spacing.xs,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelLarge?.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
