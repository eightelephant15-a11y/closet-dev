import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/auth/application/auth_flow.dart';
import 'package:stylist/features/auth/application/session_controller.dart';
import 'package:stylist/features/auth/domain/auth_provider.dart';
import 'package:stylist/features/closet/application/closet_providers.dart';
import 'package:stylist/features/settings/account_actions.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/atelier.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final session = ref.watch(sessionControllerProvider);
    final config = ref.watch(appConfigProvider);
    final remote = ref.watch(remoteConfigProvider).valueOrNull;
    final summary = ref.watch(closetSummaryProvider).valueOrNull;
    final opener = ref.read(urlOpenerProvider);
    final isGuest = session.status == SessionStatus.guest;
    final user = session.user;
    final label = isGuest
        ? l10n.settingsGuest
        : (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : (user?.email ?? '');
    final initial = label.isEmpty ? '?' : label.characters.first.toUpperCase();
    return Scaffold(
      body: PageBody(
        child: ListView(
          children: [
            Eyebrow(l10n.brandEyebrow, color: scheme.onSurfaceVariant),
            const SizedBox(height: Spacing.xs),
            Semantics(
              header: true,
              child: Text(l10n.settingsTitle, style: text.headlineLarge),
            ),
            const SizedBox(height: Spacing.md),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(RadiusTokens.xl),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: scheme.primary,
                          child: Text(
                            initial,
                            style: text.titleLarge?.copyWith(
                              color: scheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: text.titleLarge),
                            Text(
                              isGuest
                                  ? l10n.settingsGuestBody
                                  : l10n.settingsSignedInAs(user?.email ?? ''),
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (summary != null) ...[
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
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: Spacing.md,
                            children: [
                              Text(
                                l10n.settingsPlanFree,
                                style: text.titleMedium,
                              ),
                              Text(
                                l10n.closetCount(summary.used, summary.limit),
                                style: text.labelLarge?.copyWith(
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Spacing.sm),
                          ExcludeSemantics(
                            child: LinearProgressIndicator(
                              value: summary.limit == 0
                                  ? 0
                                  : (summary.used / summary.limit).clamp(0, 1),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            l10n.settingsSpotsLeft(summary.remaining),
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (isGuest) ...[
                    const SizedBox(height: Spacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _upgrade(context, ref),
                        child: Text(l10n.signInWithGoogle),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            GroupTitle(l10n.settingsPrivacySection),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.shield_outlined,
                  title: l10n.settingsConsentCentre,
                  onTap: () => context.push(SettingsRoutes.consent),
                ),
                SettingsTile(
                  icon: Icons.policy_outlined,
                  title: l10n.settingsPrivacyPolicy,
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => opener.open(
                    remote?.privacyPolicyUrl ?? config.privacyUrl,
                  ),
                ),
                SettingsTile(
                  icon: Icons.description_outlined,
                  title: l10n.settingsTerms,
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => opener.open(remote?.termsUrl ?? config.termsUrl),
                ),
              ],
            ),
            GroupTitle(l10n.settingsDataSection),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.download_outlined,
                  title: l10n.settingsExport,
                  onTap: () => context.push(SettingsRoutes.export),
                ),
                SettingsTile(
                  icon: Icons.delete_outline,
                  title: l10n.settingsDelete,
                  destructive: true,
                  onTap: () => context.push(SettingsRoutes.delete),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.logout,
                  title: l10n.settingsSignOut,
                  showChevron: false,
                  onTap: () => _signOut(context, ref),
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
          ],
        ),
      ),
    );
  }
}
