import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/core/startup/startup_timer.dart';

void main() {
  test('measures main() to first frame once and notifies listeners', () {
    var now = 1000;
    final timer = StartupTimer(nowMs: () => now);
    final seen = <int>[];
    timer
      ..whenFirstFrame(seen.add)
      ..markMainEntered();
    now = 1450;
    timer.reportFirstFrame();
    now = 9999;
    timer.reportFirstFrame(); // idempotent
    expect(timer.firstFrameMs, 450);
    expect(seen, [450]);
  });

  test('late listeners get the recorded value immediately', () {
    var now = 0;
    final timer = StartupTimer(nowMs: () => now)..markMainEntered();
    now = 800;
    timer.reportFirstFrame();
    int? got;
    timer.whenFirstFrame((ms) => got = ms);
    expect(got, 800);
  });

  test('first frame before main() was marked is ignored, not crashed on', () {
    final timer = StartupTimer(nowMs: () => 5)..reportFirstFrame();
    expect(timer.firstFrameMs, isNull);
  });

  test('budget is 2 seconds and the event is part of the taxonomy', () {
    expect(StartupTimer.budgetMs, 2000);
    expect(AnalyticsEvent.appFirstFrame.wireName, 'app_first_frame');
  });
}
