import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';

/// Emits `onboarding_abandoned` (with the last step reached) when the app is
/// backgrounded or closed mid-onboarding. Once per background trip.
class AbandonmentTracker extends ConsumerStatefulWidget {
  const AbandonmentTracker({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<AbandonmentTracker> createState() => _AbandonmentTrackerState();
}

class _AbandonmentTrackerState extends ConsumerState<AbandonmentTracker>
    with WidgetsBindingObserver {
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reported = false;
      return;
    }
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached) {
      return;
    }
    final s = ref.read(onboardingControllerProvider);
    if (_reported || s == null || s.isDone) return;
    _reported = true;
    ref.read(analyticsServiceProvider).track(
      AnalyticsEvent.onboardingAbandoned,
      {
        'last_step': s.current.wire,
        'variant': s.variant.name,
        'elapsed_ms': DateTime.now().difference(s.startedAt).inMilliseconds,
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
