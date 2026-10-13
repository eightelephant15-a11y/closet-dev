import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/features/auth/application/session_controller.dart';
import 'package:stylist/features/settings/account_actions.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
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
            Text(
              l10n.restoreTitle,
              style: Theme.of(context).textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.md),
            Text(l10n.restoreBody, textAlign: TextAlign.center),
            const SizedBox(height: Spacing.xl),
            FilledButton(
              onPressed: () =>
                  ref.read(sessionControllerProvider.notifier).restoreAccount(),
              child: Text(l10n.restoreButton),
            ),
            const SizedBox(height: Spacing.sm),
            TextButton(
              onPressed: () => ref.read(accountActionsProvider).signOut(),
              child: Text(l10n.settingsSignOut),
            ),
          ],
        ),
      ),
    );
  }
}
