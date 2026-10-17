import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  static const _art = [
    'assets/illustrations/welcome_wardrobe.svg',
    'assets/illustrations/welcome_outfits.svg',
    'assets/illustrations/welcome_morning.svg',
  ];

  void _goTo(int page) => _pages.animateToPage(
    page,
    duration: MotionTokens.medium,
    curve: MotionTokens.curve,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final guestEnabled =
        ref.watch(remoteConfigProvider).valueOrNull?.guestModeEnabled ?? true;
    final titles = [l10n.welcomeTitle1, l10n.welcomeTitle2, l10n.welcomeTitle3];
    final bodies = [l10n.welcomeBody1, l10n.welcomeBody2, l10n.welcomeBody3];
    final arts = [l10n.welcomeArt1, l10n.welcomeArt2, l10n.welcomeArt3];
    final words = [
      l10n.welcomeTab1Word,
      l10n.welcomeTab2Word,
      l10n.welcomeTab3Word,
    ];
    final subs = [
      l10n.welcomeTab1Sub,
      l10n.welcomeTab2Sub,
      l10n.welcomeTab3Sub,
    ];
    final last = _page == titles.length - 1;
    return Scaffold(
      body: PageBody(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(RadiusTokens.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm + 2,
                        vertical: Spacing.xs + 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: Spacing.xs + 2),
                          Flexible(
                            child: Text(
                              l10n.welcomePill.toUpperCase(),
                              style: text.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Visibility(
                  visible: !last,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(
                    onPressed: () => _goTo(titles.length - 1),
                    child: Text(l10n.skip),
                  ),
                ),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: titles.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => Semantics(
                  container: true,
                  label: l10n.welcomePageIndicator(i + 1, titles.length),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: Spacing.sm),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(Spacing.md),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(
                              RadiusTokens.xl,
                            ),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: SvgPicture.asset(
                              _art[i],
                              semanticsLabel: arts[i],
                            ),
                          ),
                        ),
                        const SizedBox(height: Spacing.lg),
                        Text(
                          titles[i],
                          textAlign: TextAlign.center,
                          style: text.headlineLarge,
                        ),
                        const SizedBox(height: Spacing.sm),
                        Text(
                          bodies[i],
                          textAlign: TextAlign.center,
                          style: text.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.sm),
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
                            ? scheme.primary
                            : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(RadiusTokens.pill),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.sm),
            _SlideTabs(
              selected: _page,
              words: words,
              subs: subs,
              onSelect: _goTo,
            ),
            const SizedBox(height: Spacing.md),
            if (_busy)
              const SizedBox(
                height: Spacing.minTouchTarget,
                child: LoadingView(),
              )
            else ...[
              if (guestEnabled)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () =>
                        _run(ref.read(authFlowProvider).startGuest),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            l10n.tryItFirst,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        const ExcludeSemantics(
                          child: Icon(Icons.arrow_forward, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: Spacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: scheme.surfaceContainerLowest,
                    foregroundColor: scheme.onSurface,
                  ),
                  onPressed: () =>
                      _run(ref.read(authFlowProvider).signInWithGoogle),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ExcludeSemantics(
                        child: SvgPicture.asset(
                          'assets/illustrations/google_g.svg',
                          width: 20,
                          height: 20,
                        ),
                      ),
                      const SizedBox(width: Spacing.sm + 4),
                      Flexible(
                        child: Text(
                          l10n.signInWithGoogle,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: Spacing.sm),
            Text(
              l10n.welcomeTerms,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// The three-slide outline under the dots: a segmented control that jumps to a slide.
class _SlideTabs extends StatelessWidget {
  const _SlideTabs({
    required this.selected,
    required this.words,
    required this.subs,
    required this.onSelect,
  });
  final int selected;
  final List<String> words;
  final List<String> subs;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(RadiusTokens.lg),
      ),
      child: Row(
        children: [
          for (var i = 0; i < words.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                label: '${l10n.welcomeTabTop(i + 1, words[i])}, ${subs[i]}',
                excludeSemantics: true,
                onTap: () => onSelect(i),
                child: Material(
                  color: i == selected
                      ? scheme.surfaceContainerLowest
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(RadiusTokens.md),
                  elevation: i == selected ? 1 : 0,
                  shadowColor: scheme.shadow.withValues(alpha: 0.2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(RadiusTokens.md),
                    onTap: () => onSelect(i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: Spacing.minTouchTarget,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.xs,
                          vertical: Spacing.xs + 2,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.welcomeTabTop(i + 1, words[i]).toUpperCase(),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelSmall?.copyWith(
                                color: i == selected
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              subs[i],
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(
                                color: i == selected
                                    ? scheme.onSurface
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
