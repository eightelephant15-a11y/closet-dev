import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/features/consent/application/consent_controller.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

class ConsentCentreScreen extends ConsumerWidget {
  const ConsentCentreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final consent = ref.watch(consentControllerProvider);
    final ctl = ref.read(consentControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.consentCentreTitle)),
      body: PageBody(
        child: ListView(
          children: [
            SwitchListTile(
              value: consent.analyticsOptIn ?? false,
              onChanged: (v) => ctl.setAnalytics(optIn: v),
              title: Text(l10n.consentAnalyticsTitle),
              subtitle: Text(l10n.consentAnalyticsBody),
            ),
            const Divider(),
            SwitchListTile(
              value: consent.noAiTraining,
              onChanged: (v) => ctl.setNoAiTraining(value: v),
              title: Text(l10n.consentNoAiTitle),
              subtitle: Text(l10n.consentNoAiBody),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(l10n.consentLocationTitle),
              subtitle: Text(l10n.consentLocationBody),
              onTap: ctl.markLocationExplained,
            ),
            const SizedBox(height: Spacing.md),
            Text(
              l10n.consentPolicyVersion(consent.policyVersion),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
