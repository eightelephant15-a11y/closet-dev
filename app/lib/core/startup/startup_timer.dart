import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Measures how long the Dart side takes from `main()` to the first rendered frame, and reports it
/// once (analytics event `app_first_frame` + a log line). Process-start-to-first-frame (what users
/// feel as "cold start") also includes OS/engine time before `main()`; measure that on a device with
/// `tool/measure_startup.sh` (see docs/performance.md). Budget: 2000 ms in a release build.
class StartupTimer {
  StartupTimer({int Function()? nowMs}) : _nowMs = nowMs ?? _wallClockMs;

  static final StartupTimer instance = StartupTimer();
  static const budgetMs = 2000;

  static int _wallClockMs() => DateTime.now().millisecondsSinceEpoch;

  final int Function() _nowMs;
  int? _mainEnteredAt;
  int? _firstFrameMs;
  final List<void Function(int ms)> _listeners = [];

  /// Milliseconds from [markMainEntered] to the first frame, once known.
  int? get firstFrameMs => _firstFrameMs;

  /// Call as the very first statement of `main()`.
  void markMainEntered() => _mainEnteredAt ??= _nowMs();

  /// Starts listening for the first frame. Call right after `runApp`.
  void watchFirstFrame() {
    if (_firstFrameMs != null) return;
    late TimingsCallback callback;
    callback = (_) {
      SchedulerBinding.instance.removeTimingsCallback(callback);
      reportFirstFrame();
    };
    SchedulerBinding.instance.addTimingsCallback(callback);
  }

  /// Records the first frame (idempotent). Public so tests can drive it.
  void reportFirstFrame() {
    final start = _mainEnteredAt;
    if (_firstFrameMs != null || start == null) return;
    final ms = _nowMs() - start;
    _firstFrameMs = ms;
    debugPrint('[startup] main() -> first frame: $ms ms (budget $budgetMs ms)');
    for (final l in List.of(_listeners)) {
      l(ms);
    }
    _listeners.clear();
  }

  /// Runs [onFirstFrame] when the first frame has been drawn (immediately if it already was).
  void whenFirstFrame(void Function(int ms) onFirstFrame) {
    final known = _firstFrameMs;
    if (known != null) {
      onFirstFrame(known);
    } else {
      _listeners.add(onFirstFrame);
    }
  }
}

/// Forwards the startup timing to analytics (which holds it until the user has consented).
class StartupReporter extends StatefulWidget {
  const StartupReporter({
    required this.onReport,
    required this.child,
    super.key,
  });
  final void Function(int ms) onReport;
  final Widget child;

  @override
  State<StartupReporter> createState() => _StartupReporterState();
}

class _StartupReporterState extends State<StartupReporter> {
  @override
  void initState() {
    super.initState();
    StartupTimer.instance.whenFirstFrame(widget.onReport);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
