import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stylist/features/closet/presentation/closet_routes.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

/// Placeholder for the outfits tab. Outfit generation arrives in a later phase; until then this says so
/// plainly and points back to the closet (no pretend outfits).
class OutfitsScreen extends StatelessWidget {
  const OutfitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.outfitsTitle)),
      body: PageBody(
        child: CenteredScroll(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.auto_awesome_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: Spacing.md),
            Text(
              l10n.outfitsSoonTitle,
              style: text.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              l10n.outfitsSoonBody,
              style: text.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.lg),
            FilledButton(
              onPressed: () => context.go(ClosetRoutes.root),
              child: Text(l10n.outfitsSoonCta),
            ),
          ],
        ),
      ),
    );
  }
}
