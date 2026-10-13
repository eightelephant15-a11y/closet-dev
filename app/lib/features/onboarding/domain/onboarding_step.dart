import 'package:stylist/features/config/domain/remote_config.dart';

enum OnboardingStep {
  welcome('welcome'),
  age('age'),
  quiz('quiz'),
  basics('basics'),
  permissions('permissions'),
  firstItems('first_items'),
  firstOutfit('first_outfit'),
  optional('optional'),
  done('done')
  ;

  const OnboardingStep(this.wire);
  final String wire;

  static OnboardingStep? tryParse(String s) {
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return null;
  }

  static OnboardingStep fromWire(String s) => values.firstWhere(
    (e) => e.wire == s,
    orElse: () => OnboardingStep.welcome,
  );

  String get path => '/onboarding/$wire';
}

/// Step order per `onboarding_variant`. `closet_first` moves the quiz after the
/// first-items step; the same screens are reused.
List<OnboardingStep> stepsFor(OnboardingVariant variant) => switch (variant) {
  OnboardingVariant.quizFirst => const [
    OnboardingStep.welcome,
    OnboardingStep.age,
    OnboardingStep.quiz,
    OnboardingStep.basics,
    OnboardingStep.permissions,
    OnboardingStep.firstItems,
    OnboardingStep.firstOutfit,
    OnboardingStep.optional,
  ],
  OnboardingVariant.closetFirst => const [
    OnboardingStep.welcome,
    OnboardingStep.age,
    OnboardingStep.basics,
    OnboardingStep.permissions,
    OnboardingStep.firstItems,
    OnboardingStep.quiz,
    OnboardingStep.firstOutfit,
    OnboardingStep.optional,
  ],
};
