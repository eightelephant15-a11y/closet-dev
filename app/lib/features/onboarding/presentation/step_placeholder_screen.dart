import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';
import 'package:stylist/features/onboarding/domain/onboarding_step.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/state_views.dart';

/// Temporary stand-in replaced slice by slice.
class StepPlaceholderScreen extends ConsumerWidget {
  const StepPlaceholderScreen({required this.step, super.key});
  final OnboardingStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: PageBody(
      child: Center(
        child: FilledButton(
          onPressed: () => ref
              .read(onboardingControllerProvider.notifier)
              .completeStep(step),
          child: Text(
            '${step.wire}: ${AppLocalizations.of(context).continueLabel}',
          ),
        ),
      ),
    ),
  );
}
