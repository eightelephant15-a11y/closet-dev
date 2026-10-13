import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/core/network/api_exception.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/consent/domain/consent.dart';
import 'package:stylist/features/onboarding/application/outbox_executor.dart';

final consentControllerProvider =
    NotifierProvider<ConsentController, ConsentState>(
      ConsentController.new,
    );

/// Local-first consent store. Analytics stays off until the user opts in, and
/// the decision is mirrored to the server (with timestamp and policy version).
class ConsentController extends Notifier<ConsentState> {
  static const storeKey = 'consent_v1';

  @override
  ConsentState build() {
    final raw = ref.read(keyValueStoreProvider).read(storeKey);
    final s = raw == null
        ? const ConsentState()
        : ConsentState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return s;
  }

  /// Applies the stored decision to the analytics gate (call at start-up).
  void applyToAnalytics() {
    final opt = state.analyticsOptIn;
    if (opt != null) ref.read(analyticsGateProvider).setConsent(granted: opt);
  }

  /// Pulls the server copy (new device / reinstall). Local undecided + server decided => adopt.
  Future<void> syncFromServer() async {
    try {
      final remote = await ref.read(consentRepositoryProvider).get();
      final merged = state.copyWith(
        analyticsOptIn: state.analyticsOptIn ?? remote.analyticsOptIn,
        noAiTraining: remote.noAiTraining,
        policyVersion: remote.policyVersion,
        locationExplained: state.locationExplained || remote.locationExplained,
      );
      _set(merged);
      applyToAnalytics();
    } on ApiException {
      // Offline: local values stay authoritative until the next sync.
    }
  }

  void _set(ConsentState s) {
    state = s;
    unawaited(
      ref.read(keyValueStoreProvider).write(storeKey, jsonEncode(s.toJson())),
    );
  }

  Future<void> _push(Map<String, dynamic> payload) async {
    final outbox = ref.read(outboxProvider);
    await outbox.enqueue(OutboxOps.consentsPut, payload, merge: true);
    unawaited(outbox.flush());
  }

  Future<void> setAnalytics({required bool optIn}) async {
    _set(state.copyWith(analyticsOptIn: optIn));
    ref.read(analyticsGateProvider).setConsent(granted: optIn);
    await _push({'analytics_opt_in': optIn});
  }

  Future<void> setNoAiTraining({required bool value}) async {
    _set(state.copyWith(noAiTraining: value));
    await _push({'no_ai_training': value});
  }

  Future<void> markLocationExplained() async {
    if (state.locationExplained) return;
    _set(state.copyWith(locationExplained: true));
    await _push({'location_explained': true});
  }

  Future<void> clearLocal() async {
    await ref.read(keyValueStoreProvider).remove(storeKey);
    state = const ConsentState();
  }
}
