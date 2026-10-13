import 'package:stylist/features/onboarding/domain/quiz.dart';

/// Versioned preference weights derived from quiz answers. Mirrors
/// `api/app/domain/preferences.py` (model version 1) so the app can rank
/// locally (mock mode, offline) and the server stays authoritative.
class PreferenceModel {
  const PreferenceModel({
    required this.version,
    required this.fit,
    required this.colors,
    required this.formality,
    required this.goals,
    required this.blocked,
  });

  factory PreferenceModel.fromAnswers(QuizAnswers a) {
    final never = a.neverWear ?? const <NeverWear>{};
    final colors = {
      for (final c in ClothingColor.values) c: a.colors.contains(c) ? 1.0 : 0.0,
    };
    if (never.contains(NeverWear.brightColors)) {
      for (final c in brightColors) {
        colors[c] = -1; // explicit dislike overrides a favourite
      }
    }
    return PreferenceModel(
      version: modelVersion,
      fit: {for (final f in Fit.values) f: a.fit == f ? 1.0 : 0.0},
      colors: colors,
      formality: a.dressCode == null
          ? null
          : a.dressCode! / (dressCodeLevels - 1),
      goals: {
        for (final g in Goal.values)
          g: (a.goals?.contains(g) ?? false) ? 1.0 : 0.0,
      },
      blocked: never.where((n) => n != NeverWear.brightColors).toSet(),
    );
  }

  static const modelVersion = 1;

  final int version;
  final Map<Fit, double> fit;
  final Map<ClothingColor, double> colors;
  final double? formality;
  final Map<Goal, double> goals;
  final Set<NeverWear> blocked;
}
