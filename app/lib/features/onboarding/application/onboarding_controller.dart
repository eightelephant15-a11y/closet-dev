import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/core/network/api_exception.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/auth/application/session_controller.dart';
import 'package:stylist/features/onboarding/application/outbox_executor.dart';
import 'package:stylist/features/onboarding/domain/onboarding_state.dart';
import 'package:stylist/features/onboarding/domain/onboarding_step.dart';
import 'package:stylist/features/onboarding/domain/quiz.dart';

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState?>(
      OnboardingController.new,
    );

/// Local-first onboarding state machine. Every change is persisted locally,
/// queued for server sync, and survives an app kill (resume at the same step).
class OnboardingController extends Notifier<OnboardingState?> {
  static const storeKey = 'onboarding_state_v1';
  static const blockedKey = 'age_blocked';

  DateTime Function() clock = DateTime.now;

  @override
  OnboardingState? build() => null;

  // ---- infrastructure -----------------------------------------------------

  void _persist() {
    final s = state;
    if (s != null) {
      unawaited(
        ref.read(keyValueStoreProvider).write(storeKey, jsonEncode(s.toJson())),
      );
    }
  }

  void _set(OnboardingState s) {
    state = s;
    _persist();
  }

  Future<void> _enqueue(
    String type,
    Map<String, dynamic> payload, {
    bool merge = false,
  }) async {
    final outbox = ref.read(outboxProvider);
    await outbox.enqueue(type, payload, merge: merge);
    unawaited(outbox.flush());
  }

  Map<String, dynamic> _statePayload(
    OnboardingState s, {
    bool completed = false,
  }) => {
    'current_step': s.current.wire,
    'completed_steps': s.completed.map((e) => e.wire).toList(),
    if (s.timeToFirstOutfitMs != null)
      'time_to_first_outfit_ms': s.timeToFirstOutfitMs,
    if (completed) 'completed': true,
  };

  void _syncState({bool completed = false}) => unawaited(
    _enqueue(
      OutboxOps.onboardingPut,
      _statePayload(state!, completed: completed),
    ),
  );

  // ---- lifecycle -----------------------------------------------------------

  bool get isBlocked =>
      ref.read(keyValueStoreProvider).read(blockedKey) != null;

  /// Loads local state (resume after kill). Call once at start-up.
  void loadLocal() {
    final raw = ref.read(keyValueStoreProvider).read(storeKey);
    if (raw != null) {
      state = OnboardingState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
  }

  /// Called once a session exists (guest or member). Creates the local state
  /// for a first run, or merges the server's view (second device / reinstall).
  Future<void> startOrResume() async {
    final config = await ref.read(remoteConfigProvider.future);
    final repo = ref.read(onboardingRepositoryProvider);
    final isFresh = state == null;
    state ??= OnboardingState.initial(config.onboardingVariant, clock());
    try {
      final remote = await repo.getState();
      var s = state!;
      // Server pins the variant on first read; adopt it so both devices agree.
      s = OnboardingState(
        variant: remote.variant,
        startedAt: s.startedAt,
        current: s.current,
        completed: s.completed,
        quiz: s.quiz,
        quizIndex: s.quizIndex,
        displayName: s.displayName,
        units: s.units,
        city: s.city,
        permissions: s.permissions,
        usedSampleCloset: s.usedSampleCloset,
        firstItemsCount: s.firstItemsCount,
        notificationTime: s.notificationTime,
        timeToFirstOutfitMs:
            s.timeToFirstOutfitMs ?? remote.timeToFirstOutfitMs,
        completedAt: s.completedAt ?? remote.completedAt,
      );
      final completed = {...s.completed, ...remote.completed};
      final order = s.order;
      final furthest = order.indexOf(s.current) >= order.indexOf(remote.current)
          ? s.current
          : remote.current;
      s = s.copyWith(
        completed: completed,
        current: remote.completedAt != null ? OnboardingStep.done : furthest,
      );
      if (isFresh && remote.completed.isNotEmpty) {
        // New device for an existing user: pull answers and profile.
        final answers = await repo.getPreferenceAnswers();
        if (answers.isNotEmpty) {
          s = s.copyWith(quiz: QuizAnswers.fromJson(answers));
        }
        final me = ref.read(sessionControllerProvider).user;
        if (me != null) {
          s = s.copyWith(
            displayName: me.displayName,
            units: me.units,
            city: me.city,
          );
        }
      }
      state = s;
      _persist();
    } on ApiException {
      // Offline: continue from local state; it will sync later.
    }
    if (isFresh) {
      ref.read(analyticsServiceProvider).track(
        AnalyticsEvent.onboardingStarted,
        {
          'variant': state!.variant.name,
        },
      );
      _syncState();
    }
    unawaited(ref.read(outboxProvider).flush());
  }

  Future<void> reset() async {
    state = null;
    final store = ref.read(keyValueStoreProvider);
    await store.remove(storeKey);
    await ref.read(outboxProvider).clear();
  }

  // ---- steps ----------------------------------------------------------------

  void completeStep(
    OnboardingStep step, {
    OnboardingState Function(OnboardingState)? update,
  }) {
    var s = state!;
    if (update != null) s = update(s);
    final completed = {...s.completed, step};
    final next = s.nextAfter(step);
    if (next == null) {
      state = s.copyWith(completed: completed);
      finish();
      return;
    }
    // Never move backwards when re-completing an earlier step.
    final order = s.order;
    final current = order.indexOf(next) > order.indexOf(s.current)
        ? next
        : s.current;
    _set(s.copyWith(completed: completed, current: current));
    _syncState();
  }

  void finish() {
    final s = state!;
    if (s.isDone) return;
    _set(s.copyWith(current: OnboardingStep.done, completedAt: clock()));
    _syncState(completed: true);
    ref.read(analyticsServiceProvider).track(
      AnalyticsEvent.onboardingCompleted,
      {
        'variant': s.variant.name,
        'duration_ms': clock().difference(s.startedAt).inMilliseconds,
        'time_to_first_outfit_ms': s.timeToFirstOutfitMs,
      },
    );
  }

  // ---- age ------------------------------------------------------------------

  Future<void> confirmAge() async {
    ref.read(analyticsServiceProvider).track(AnalyticsEvent.ageConfirmed);
    await _enqueue(OutboxOps.ageConfirm, {'ok': true});
    completeStep(OnboardingStep.age);
  }

  /// Under 16: no account data kept. Marks the device as blocked, deletes the
  /// server account (retried at next start if offline) and wipes local data.
  Future<void> rejectAge() async {
    final store = ref.read(keyValueStoreProvider);
    await store.write(blockedKey, '1');
    await _purgeBlockedAccount();
  }

  Future<void> _purgeBlockedAccount() async {
    try {
      await ref.read(onboardingRepositoryProvider).rejectAge();
    } on ApiException catch (e) {
      if (e.isOffline) return; // retried via retryBlockedPurge()
      // age_under_minimum means the server deleted everything.
    }
    await reset();
    await ref.read(sessionControllerProvider.notifier).signOut();
  }

  Future<void> retryBlockedPurge() async {
    if (isBlocked && ref.read(sessionControllerProvider).isSignedIn) {
      await _purgeBlockedAccount();
    }
  }

  // ---- quiz -----------------------------------------------------------------

  void answerQuiz(QuizQuestion q, QuizAnswers Function(QuizAnswers) change) {
    final s = state!;
    final quiz = change(s.quiz);
    _set(s.copyWith(quiz: quiz));
    ref.read(analyticsServiceProvider).track(
      AnalyticsEvent.quizQuestionAnswered,
      {
        'question': q.name,
        'index': q.index,
      },
    );
    unawaited(_enqueue(OutboxOps.preferencesPut, quiz.toJson()));
    if (q == QuizQuestion.department && quiz.department != null) {
      unawaited(
        _enqueue(OutboxOps.userPatch, {
          'clothing_department': quiz.department!.name,
        }, merge: true),
      );
    }
  }

  void setQuizIndex(int i) {
    if (state!.quizIndex != i) _set(state!.copyWith(quizIndex: i));
  }

  void completeQuiz() {
    ref.read(analyticsServiceProvider).track(AnalyticsEvent.quizCompleted, {
      'questions': QuizQuestion.values.length,
    });
    completeStep(OnboardingStep.quiz);
  }
}
