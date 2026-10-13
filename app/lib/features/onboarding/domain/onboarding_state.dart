import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/config/domain/remote_config.dart';
import 'package:stylist/features/onboarding/domain/onboarding_step.dart';
import 'package:stylist/features/onboarding/domain/quiz.dart';

enum PermissionKind { camera, photos, location, notifications }

enum PermissionOutcome { granted, denied, skipped }

class OnboardingState {
  const OnboardingState({
    required this.variant,
    required this.startedAt,
    this.current = OnboardingStep.welcome,
    this.completed = const {},
    this.quiz = const QuizAnswers(),
    this.quizIndex = 0,
    this.displayName,
    this.units = Units.imperial,
    this.city,
    this.permissions = const {},
    this.usedSampleCloset = false,
    this.firstItemsCount = 0,
    this.notificationTime,
    this.timeToFirstOutfitMs,
    this.completedAt,
  });

  factory OnboardingState.initial(OnboardingVariant variant, DateTime now) =>
      OnboardingState(variant: variant, startedAt: now);

  factory OnboardingState.fromJson(Map<String, dynamic> j) => OnboardingState(
    variant: j['variant'] == 'closet_first'
        ? OnboardingVariant.closetFirst
        : OnboardingVariant.quizFirst,
    startedAt: DateTime.parse(j['started_at'] as String),
    current: OnboardingStep.fromWire(j['current'] as String),
    completed: {
      for (final s in (j['completed'] as List))
        OnboardingStep.fromWire(s as String),
    },
    quiz: QuizAnswers.fromJson((j['quiz'] as Map).cast<String, dynamic>()),
    quizIndex: j['quiz_index'] as int? ?? 0,
    displayName: j['display_name'] as String?,
    units: Units.values.byName(j['units'] as String? ?? 'imperial'),
    city: j['city'] as String?,
    permissions: {
      for (final e in ((j['permissions'] as Map?) ?? const {}).entries)
        PermissionKind.values.byName(e.key as String): PermissionOutcome.values
            .byName(
              e.value as String,
            ),
    },
    usedSampleCloset: j['used_sample_closet'] as bool? ?? false,
    firstItemsCount: j['first_items_count'] as int? ?? 0,
    notificationTime: j['notification_time'] as String?,
    timeToFirstOutfitMs: j['time_to_first_outfit_ms'] as int?,
    completedAt: j['completed_at'] == null
        ? null
        : DateTime.parse(j['completed_at'] as String),
  );

  final OnboardingVariant variant;
  final DateTime startedAt;
  final OnboardingStep current;
  final Set<OnboardingStep> completed;
  final QuizAnswers quiz;
  final int quizIndex;
  final String? displayName;
  final Units units;
  final String? city;
  final Map<PermissionKind, PermissionOutcome> permissions;
  final bool usedSampleCloset;
  final int firstItemsCount;

  /// "HH:mm" local time for the daily outfit notification.
  final String? notificationTime;
  final int? timeToFirstOutfitMs;
  final DateTime? completedAt;

  bool get isDone => completedAt != null;
  List<OnboardingStep> get order => stepsFor(variant);

  /// 0-based index of the current step in [order] (-1 when done).
  int get currentIndex => order.indexOf(current);

  OnboardingStep? nextAfter(OnboardingStep step) {
    final i = order.indexOf(step);
    return i < 0 || i + 1 >= order.length ? null : order[i + 1];
  }

  OnboardingState copyWith({
    OnboardingStep? current,
    Set<OnboardingStep>? completed,
    QuizAnswers? quiz,
    int? quizIndex,
    String? displayName,
    Units? units,
    String? city,
    Map<PermissionKind, PermissionOutcome>? permissions,
    bool? usedSampleCloset,
    int? firstItemsCount,
    String? notificationTime,
    int? timeToFirstOutfitMs,
    DateTime? completedAt,
  }) => OnboardingState(
    variant: variant,
    startedAt: startedAt,
    current: current ?? this.current,
    completed: completed ?? this.completed,
    quiz: quiz ?? this.quiz,
    quizIndex: quizIndex ?? this.quizIndex,
    displayName: displayName ?? this.displayName,
    units: units ?? this.units,
    city: city ?? this.city,
    permissions: permissions ?? this.permissions,
    usedSampleCloset: usedSampleCloset ?? this.usedSampleCloset,
    firstItemsCount: firstItemsCount ?? this.firstItemsCount,
    notificationTime: notificationTime ?? this.notificationTime,
    timeToFirstOutfitMs: timeToFirstOutfitMs ?? this.timeToFirstOutfitMs,
    completedAt: completedAt ?? this.completedAt,
  );

  Map<String, dynamic> toJson() => {
    'variant': variant == OnboardingVariant.closetFirst
        ? 'closet_first'
        : 'quiz_first',
    'started_at': startedAt.toIso8601String(),
    'current': current.wire,
    'completed': completed.map((s) => s.wire).toList(),
    'quiz': quiz.toJson(),
    'quiz_index': quizIndex,
    'display_name': displayName,
    'units': units.name,
    'city': city,
    'permissions': {
      for (final e in permissions.entries) e.key.name: e.value.name,
    },
    'used_sample_closet': usedSampleCloset,
    'first_items_count': firstItemsCount,
    'notification_time': notificationTime,
    'time_to_first_outfit_ms': timeToFirstOutfitMs,
    'completed_at': completedAt?.toIso8601String(),
  };
}
