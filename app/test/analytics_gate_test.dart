import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/core/analytics/analytics_service.dart';

void main() {
  test(
    'nothing reaches the backend before opt-in; opt-in flushes the buffer',
    () {
      final inner = RecordingAnalytics();
      final gate = ConsentGatedAnalytics(inner)
        ..identify('u1')
        ..track(AnalyticsEvent.welcomeViewed);
      expect(inner.events, isEmpty);
      expect(inner.userId, isNull);
      gate.setConsent(granted: true);
      expect(inner.names, [AnalyticsEvent.welcomeViewed]);
      expect(inner.userId, 'u1');
      gate.track(AnalyticsEvent.ageConfirmed);
      expect(inner.names, hasLength(2));
    },
  );

  test('opt-out discards buffered and future events', () {
    final inner = RecordingAnalytics();
    final gate = ConsentGatedAnalytics(inner)
      ..track(AnalyticsEvent.welcomeViewed);
    gate.setConsent(granted: false);
    gate.track(AnalyticsEvent.ageConfirmed);
    expect(inner.events, isEmpty);
  });

  test('revoking consent after opt-in stops events', () {
    final inner = RecordingAnalytics();
    final gate = ConsentGatedAnalytics(inner)..setConsent(granted: true);
    gate.track(AnalyticsEvent.welcomeViewed);
    gate.setConsent(granted: false);
    gate.track(AnalyticsEvent.ageConfirmed);
    expect(inner.names, [AnalyticsEvent.welcomeViewed]);
  });

  test('event wire names are unique snake_case', () {
    final names = AnalyticsEvent.values.map((e) => e.wireName).toList();
    expect(names.toSet(), hasLength(names.length));
    expect(names.every((n) => RegExp(r'^[a-z_]+$').hasMatch(n)), isTrue);
  });
}
