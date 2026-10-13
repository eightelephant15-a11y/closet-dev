import 'package:flutter/material.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

/// Shown to people under 16. No navigation away and no data kept.
class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: PageBody(
        child: CenteredScroll(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.favorite_border,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              l10n.blockedTitle,
              style: Theme.of(context).textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.md),
            Text(l10n.blockedBody, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
