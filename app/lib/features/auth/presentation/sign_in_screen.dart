import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/features/auth/application/auth_flow.dart';
import 'package:stylist/features/auth/domain/auth_provider.dart';
import 'package:stylist/features/onboarding/presentation/error_text.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

/// Sign-in only (shown straight away when `guest_mode_enabled` is false).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(authFlowProvider).signInWithGoogle();
    } on AuthCancelled {
      // ignore
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: PageBody(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.signInTitle,
              style: Theme.of(context).textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.md),
            Text(l10n.signInBody, textAlign: TextAlign.center),
            const SizedBox(height: Spacing.xl),
            if (_busy)
              const LoadingView()
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _signIn,
                  child: Text(l10n.signInWithGoogle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
