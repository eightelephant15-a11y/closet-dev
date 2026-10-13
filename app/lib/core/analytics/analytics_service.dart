import 'package:stylist/core/analytics/analytics_event.dart';

typedef EventProps = Map<String, Object?>;

abstract class AnalyticsService {
  void track(AnalyticsEvent event, [EventProps props = const {}]);
  void identify(String userId);
  void reset();
}

class NoopAnalytics implements AnalyticsService {
  @override
  void track(AnalyticsEvent event, [EventProps props = const {}]) {}
  @override
  void identify(String userId) {}
  @override
  void reset() {}
}

/// Records events (tests, mock mode).
class RecordingAnalytics implements AnalyticsService {
  final List<({AnalyticsEvent event, EventProps props})> events = [];
  String? userId;

  @override
  void track(AnalyticsEvent event, [EventProps props = const {}]) =>
      events.add((event: event, props: Map.of(props)));

  @override
  void identify(String userId) => this.userId = userId;

  @override
  void reset() => userId = null;

  Iterable<EventProps> propsOf(AnalyticsEvent e) =>
      events.where((x) => x.event == e).map((x) => x.props);
  List<AnalyticsEvent> get names => events.map((e) => e.event).toList();
}

/// Holds events in memory until the user decides on analytics consent.
/// Opt-in flushes them to [_inner]; opt-out discards them. Nothing leaves the
/// device before opt-in.
class ConsentGatedAnalytics implements AnalyticsService {
  ConsentGatedAnalytics(this._inner, {this.maxBuffered = 200});

  final AnalyticsService _inner;
  final int maxBuffered;
  bool? _consent; // null = undecided
  String? _pendingUserId;
  final List<({AnalyticsEvent event, EventProps props})> _buffer = [];

  bool? get consent => _consent;

  void setConsent({required bool granted}) {
    _consent = granted;
    if (granted) {
      final uid = _pendingUserId;
      if (uid != null) _inner.identify(uid);
      for (final e in _buffer) {
        _inner.track(e.event, e.props);
      }
    } else {
      _inner.reset();
    }
    _buffer.clear();
    _pendingUserId = null;
  }

  @override
  void track(AnalyticsEvent event, [EventProps props = const {}]) {
    switch (_consent) {
      case true:
        _inner.track(event, props);
      case null:
        if (_buffer.length < maxBuffered) {
          _buffer.add((event: event, props: Map.of(props)));
        }
      case false:
        break;
    }
  }

  @override
  void identify(String userId) {
    switch (_consent) {
      case true:
        _inner.identify(userId);
      case null:
        _pendingUserId = userId;
      case false:
        break;
    }
  }

  @override
  void reset() {
    _pendingUserId = null;
    _buffer.clear();
    _inner.reset();
  }
}
