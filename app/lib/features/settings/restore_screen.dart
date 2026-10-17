import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/features/auth/application/session_controller.dart';
import 'package:stylist/features/settings/account_actions.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/atelier.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

/// Shown when someone signs in during the 30-day deletion window.
class RestoreScreen extends ConsumerWidget {
  const RestoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: PageBody(
        child: CenteredScroll(
          children: [
            const Center(
              child: BadgeIcon(icon: Icons.hourglass_bottom_outlined),
            ),
            const SizedBox(height: Spacing.lg),
            Eyebrow(l10n.restoreEyebrow, align: TextAlign.center),
            const SizedBox(height: Spacing.xs),
            Text(
              l10n.restoreTitle,
              style: Theme.of(context).textTheme.headlineLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              l10n.restoreBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.xl),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () => ref
                    .read(sessionControllerProvider.notifier)
                    .restoreAccount(),
                child: Text(l10n.restoreButton),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerLowest,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () => ref.read(accountActionsProvider).signOut(),
              child: Text(l10n.settingsSignOut),
            ),
          ],
        ),
      ),
    );
  }
}
