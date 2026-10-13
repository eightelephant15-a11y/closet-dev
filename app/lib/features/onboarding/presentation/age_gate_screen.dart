import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/features/consent/presentation/consent_prompt.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

class AgeGateScreen extends ConsumerWidget {
  const AgeGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ctl = ref.read(onboardingControllerProvider.notifier);
    return Scaffold(
      body: PageBody(
        child: CenteredScroll(
          children: [
            Text(
              l10n.ageTitle,
              style: Theme.of(context).textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.md),
            Text(l10n.ageBody, textAlign: TextAlign.center),
            const SizedBox(height: Spacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await askAnalyticsConsentIfNeeded(context, ref);
                  await ctl.confirmAge();
                },
                child: Text(l10n.ageConfirmButton),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: ctl.rejectAge,
                child: Text(l10n.ageUnderButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
