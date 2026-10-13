import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/features/consent/application/consent_controller.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';

/// One-time analytics question, shown right after the age check. No tracking
/// leaves the device before the user says yes.
Future<void> askAnalyticsConsentIfNeeded(
  BuildContext context,
  WidgetRef ref,
) async {
  final consent = ref.read(consentControllerProvider);
  if (consent.analyticsDecided) return;
  final l10n = AppLocalizations.of(context);
  final controller = ref.read(consentControllerProvider.notifier);
  final granted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.consentPromptTitle),
      content: Text(l10n.consentPromptBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.consentDecline),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.consentAllow),
        ),
      ],
    ),
  );
  await controller.setAnalytics(optIn: granted ?? false);
}
