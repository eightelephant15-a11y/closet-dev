import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/core/providers.dart';

/// Emits whenever the device's network state changes.
final connectivityChangesProvider = Provider<Stream<void>>((ref) {
  try {
    return Connectivity().onConnectivityChanged.map((_) {});
  } on Object {
    return const Stream<void>.empty();
  }
});

/// Flushes the offline outbox when the network comes back or the app returns
/// to the foreground, so onboarding data queued offline syncs by itself.
class SyncTriggers extends ConsumerStatefulWidget {
  const SyncTriggers({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<SyncTriggers> createState() => _SyncTriggersState();
}

class _SyncTriggersState extends ConsumerState<SyncTriggers>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = ref.read(connectivityChangesProvider).listen((_) => _flush());
  }

  void _flush() => unawaited(ref.read(outboxProvider).flush());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _flush();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
