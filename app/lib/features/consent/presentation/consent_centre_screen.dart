import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/features/consent/application/consent_controller.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/atelier.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

class ConsentCentreScreen extends ConsumerWidget {
  const ConsentCentreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final consent = ref.watch(consentControllerProvider);
    final ctl = ref.read(consentControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.consentCentreTitle)),
      body: PageBody(
        child: ListView(
          children: [
            Eyebrow(l10n.privacyEyebrow),
            const SizedBox(height: Spacing.xs),
            Text(l10n.privacyIntro, style: text.headlineMedium),
            const SizedBox(height: Spacing.md),
            NoteCard(
              icon: Icons.shield_outlined,
              title: l10n.privacyNoteTitle,
              child: Text(l10n.privacyNoteBody),
            ),
            const SizedBox(height: Spacing.md),
            _SwitchCard(
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.xs,
                ),
                value: consent.analyticsOptIn ?? false,
                onChanged: (v) => ctl.setAnalytics(optIn: v),
                title: Text(
                  l10n.consentAnalyticsTitle,
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(l10n.consentAnalyticsBody),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            _SwitchCard(
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.xs,
                ),
                value: consent.noAiTraining,
                onChanged: (v) => ctl.setNoAiTraining(value: v),
                title: Text(
                  l10n.consentNoAiTitle,
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(l10n.consentNoAiBody),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.location_on_outlined,
                  title: l10n.consentLocationTitle,
                  subtitle: l10n.consentLocationBody,
                  showChevron: false,
                  onTap: ctl.markLocationExplained,
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              l10n.consentPolicyVersion(consent.policyVersion),
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(RadiusTokens.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}
