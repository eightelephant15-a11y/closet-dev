import 'dart:async';

import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/core/analytics/analytics_service.dart';

/// PostHog backend. Only ever called through `ConsentGatedAnalytics`, so SDK
/// setup (and therefore any network traffic) happens after the user opts in.
class PostHogAnalyticsService implements AnalyticsService {
  PostHogAnalyticsService({
    required this.apiKey,
    this.host = 'https://us.i.posthog.com',
  });

  final String apiKey;
  final String host;
  Future<void>? _ready;

  Future<void> _ensureSetup() => _ready ??= Posthog().setup(
    PostHogConfig(apiKey)
      ..host = host
      ..captureApplicationLifecycleEvents = false
      ..debug = false,
  );

  static Map<String, Object> _clean(EventProps props) => {
    for (final e in props.entries)
      if (e.value != null) e.key: e.value!,
  };

  @override
  void track(AnalyticsEvent event, [EventProps props = const {}]) {
    unawaited(
      _ensureSetup().then(
        (_) => Posthog().capture(
          eventName: event.wireName,
          properties: _clean(props),
        ),
      ),
    );
  }

  @override
  void identify(String userId) {
    unawaited(_ensureSetup().then((_) => Posthog().identify(userId: userId)));
  }

  @override
  void reset() {
    final ready = _ready;
    if (ready != null) unawaited(ready.then((_) => Posthog().reset()));
  }
}
