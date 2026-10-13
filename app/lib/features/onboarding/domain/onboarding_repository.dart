import 'package:stylist/features/config/domain/remote_config.dart';
import 'package:stylist/features/onboarding/domain/onboarding_step.dart';

class RemoteOnboarding {
  const RemoteOnboarding({
    required this.variant,
    required this.current,
    required this.completed,
    this.completedAt,
    this.timeToFirstOutfitMs,
  });

  factory RemoteOnboarding.fromJson(Map<String, dynamic> j) => RemoteOnboarding(
    variant: j['variant'] == 'closet_first'
        ? OnboardingVariant.closetFirst
        : OnboardingVariant.quizFirst,
    current: OnboardingStep.fromWire(j['current_step'] as String),
    completed: {
      for (final s in (j['completed_steps'] as List))
        OnboardingStep.fromWire(s as String),
    },
    completedAt: j['completed_at'] == null
        ? null
        : DateTime.parse(j['completed_at'] as String),
    timeToFirstOutfitMs: j['time_to_first_outfit_ms'] as int?,
  );

  final OnboardingVariant variant;
  final OnboardingStep current;
  final Set<OnboardingStep> completed;
  final DateTime? completedAt;
  final int? timeToFirstOutfitMs;
}

/// Server-side onboarding API. All calls are idempotent.
abstract class OnboardingRepository {
  Future<RemoteOnboarding> getState();

  /// `PUT /v1/onboarding` with `{current_step, completed_steps, completed?, ...}`.
  Future<void> putState(Map<String, dynamic> payload);

  Future<void> confirmAge();

  /// Under-16: the server deletes the account. Throws `age_under_minimum` ApiException.
  Future<void> rejectAge();

  Future<Map<String, dynamic>> getPreferenceAnswers();
  Future<void> putPreferences(Map<String, dynamic> answers);
}
