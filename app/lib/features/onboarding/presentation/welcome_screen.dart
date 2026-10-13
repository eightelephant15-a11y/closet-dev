import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/auth/application/auth_flow.dart';
import 'package:stylist/features/auth/domain/auth_provider.dart';
import 'package:stylist/features/onboarding/presentation/error_text.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _pages = PageController();
  int _page = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(analyticsServiceProvider).track(AnalyticsEvent.welcomeViewed);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } on AuthCancelled {
      // User backed out of the Google sheet: nothing to report.
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final guestEnabled =
        ref.watch(remoteConfigProvider).valueOrNull?.guestModeEnabled ?? true;
    final titles = [l10n.welcomeTitle1, l10n.welcomeTitle2, l10n.welcomeTitle3];
    final bodies = [l10n.welcomeBody1, l10n.welcomeBody2, l10n.welcomeBody3];
    final last = _page == titles.length - 1;
    return Scaffold(
      body: PageBody(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Visibility(
                visible: !last,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: TextButton(
                  onPressed: () => _pages.animateToPage(
                    titles.length - 1,
                    duration: MotionTokens.medium,
                    curve: MotionTokens.curve,
                  ),
                  child: Text(l10n.skip),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: titles.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => Semantics(
                  label: l10n.welcomePageIndicator(i + 1, titles.length),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: Spacing.xl),
                        ExcludeSemantics(
                          child: Icon(
                            [
                              Icons.checkroom,
                              Icons.auto_awesome,
                              Icons.wb_sunny_outlined,
                            ][i],
                            size: 96,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: Spacing.lg),
                        Text(
                          titles[i],
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: Spacing.md),
                        Text(
                          bodies[i],
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < titles.length; i++)
                    AnimatedContainer(
                      duration: MotionTokens.fast,
                      margin: const EdgeInsets.all(Spacing.xs),
                      width: i == _page ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                        borderRadius: BorderRadius.circular(RadiusTokens.pill),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),
            if (_busy)
              const SizedBox(
                height: Spacing.minTouchTarget,
                child: LoadingView(),
              )
            else ...[
              if (guestEnabled)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () =>
                        _run(ref.read(authFlowProvider).startGuest),
                    child: Text(l10n.tryItFirst),
                  ),
                ),
              const SizedBox(height: Spacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      _run(ref.read(authFlowProvider).signInWithGoogle),
                  child: Text(l10n.signInWithGoogle),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
