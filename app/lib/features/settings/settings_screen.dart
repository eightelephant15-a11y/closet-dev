import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/auth/application/auth_flow.dart';
import 'package:stylist/features/auth/application/session_controller.dart';
import 'package:stylist/features/auth/domain/auth_provider.dart';
import 'package:stylist/features/settings/account_actions.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/state_views.dart';

abstract final class SettingsRoutes {
  static const root = '/settings';
  static const consent = '/settings/consent';
  static const export = '/settings/export';
  static const delete = '/settings/delete';
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.signOutConfirmTitle),
        content: Text(l10n.signOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.settingsSignOut),
          ),
        ],
      ),
    );
    if (ok ?? false) await ref.read(accountActionsProvider).signOut();
  }

  Future<void> _upgrade(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authFlowProvider).upgradeGuest();
    } on AuthCancelled {
      // ignore
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.signInFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionControllerProvider);
    final config = ref.watch(appConfigProvider);
    final remote = ref.watch(remoteConfigProvider).valueOrNull;
    final opener = ref.read(urlOpenerProvider);
    final isGuest = session.status == SessionStatus.guest;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: PageBody(
        child: ListView(
          children: [
            _Header(l10n.settingsAccount),
            if (isGuest)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(l10n.settingsGuest),
                subtitle: Text(l10n.settingsGuestBody),
                trailing: FilledButton(
                  onPressed: () => _upgrade(context, ref),
                  child: Text(l10n.signInWithGoogle),
                ),
              )
            else
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(l10n.settingsSignedInAs(session.user?.email ?? '')),
              ),
            _Header(l10n.settingsPrivacySection),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l10n.settingsConsentCentre),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(SettingsRoutes.consent),
            ),
            ListTile(
              leading: const Icon(Icons.policy_outlined),
              title: Text(l10n.settingsPrivacyPolicy),
              onTap: () =>
                  opener.open(remote?.privacyPolicyUrl ?? config.privacyUrl),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.settingsTerms),
              onTap: () => opener.open(remote?.termsUrl ?? config.termsUrl),
            ),
            _Header(l10n.settingsDataSection),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(l10n.settingsExport),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(SettingsRoutes.export),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(l10n.settingsDelete),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(SettingsRoutes.delete),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(l10n.settingsSignOut),
              onTap: () => _signOut(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    ),
  );
}
