import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/features/auth/application/boot.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/state_views.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final boot = ref.watch(bootProvider);
    return Scaffold(
      body: boot.when(
        data: (_) => const LoadingView(),
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: l10n.errorGeneric,
          onRetry: () => ref.invalidate(bootProvider),
        ),
      ),
    );
  }
}
