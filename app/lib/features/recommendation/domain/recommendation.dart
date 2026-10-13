import 'package:stylist/features/closet/domain/closet_item.dart';
import 'package:stylist/features/onboarding/domain/preference_model.dart';
import 'package:stylist/features/onboarding/domain/quiz.dart';

enum WhyKind { favouriteColor, dressCode, goal, versatile }

/// Structured "why" so the UI can localise it (no strings in domain code).
class Why {
  const Why(this.kind, {this.color, this.level, this.goal});
  final WhyKind kind;
  final ClothingColor? color;
  final int? level;
  final Goal? goal;
}

class Outfit {
  const Outfit({required this.items, required this.why, required this.score});
  final List<ClosetItem> items;
  final Why why;
  final double score;
}

class FirstOutfits {
  const FirstOutfits({required this.primary, required this.alternatives});
  final Outfit primary;
  final List<Outfit> alternatives;
}

/// Seam for the real engine (Phase 3). Phase 1 ships [FakeRecommendationService].
abstract class RecommendationService {
  /// Returns null if the closet cannot form an outfit yet.
  Future<FirstOutfits?> firstOutfits({
    required PreferenceModel prefs,
    required QuizAnswers answers,
    required List<ClosetItem> closet,
  });
}

/// Deterministic on-device stand-in: scores top+bottom+shoes / dress+shoes
/// combinations against the preference weights.
class FakeRecommendationService implements RecommendationService {
  @override
  Future<FirstOutfits?> firstOutfits({
    required PreferenceModel prefs,
    required QuizAnswers answers,
    required List<ClosetItem> closet,
  }) async {
    final usable = closet
        .where(
          (i) =>
              i.fitsDepartment(answers.department) &&
              !i.isBlockedBy(prefs.blocked),
        )
        .toList();
    List<ClosetItem> of(ItemCategory c) =>
        usable.where((i) => i.category == c).toList();
    final tops = of(ItemCategory.top);
    final bottoms = of(ItemCategory.bottom);
    final dresses = of(ItemCategory.dress);
    final shoes = of(ItemCategory.shoes);
    final outer = of(ItemCategory.outerwear);

    final combos = <List<ClosetItem>>[
      for (final t in tops)
        for (final b in bottoms)
          for (final s in shoes) [t, b, s],
      for (final d in dresses)
        for (final s in shoes) [d, s],
    ];
    if (combos.isEmpty) return null;

    final scored =
        combos.map((c) {
          final formal = prefs.formality;
          final avg =
              c.map((i) => i.formality).reduce((a, b) => a + b) / c.length;
          // Add a layer when the user dresses up and we have one.
          final withLayer =
              (formal != null && formal >= 0.6 && outer.isNotEmpty)
              ? [...c, outer.first]
              : c;
          return _score(withLayer, avg, prefs);
        }).toList()..sort((a, b) {
          final byScore = b.score.compareTo(a.score);
          return byScore != 0
              ? byScore
              : a.items
                    .map((i) => i.id)
                    .join()
                    .compareTo(b.items.map((i) => i.id).join());
        });

    final picked = <Outfit>[scored.first];
    // Alternatives must differ from what is already chosen (share at most one item).
    for (final o in scored.skip(1)) {
      if (picked.length == 3) break;
      final ids = o.items.map((i) => i.id).toSet();
      final tooSimilar = picked.any(
        (p) => p.items.where((i) => ids.contains(i.id)).length > 1,
      );
      if (!tooSimilar) picked.add(o);
    }
    for (final o in scored) {
      if (picked.length == 3) break;
      if (!picked.contains(o)) picked.add(o);
    }
    return FirstOutfits(
      primary: picked.first,
      alternatives: picked.skip(1).toList(),
    );
  }

  Outfit _score(
    List<ClosetItem> items,
    double avgFormality,
    PreferenceModel prefs,
  ) {
    var colorScore = 0.0;
    ClothingColor? bestColor;
    var bestColorWeight = 0.0;
    for (final i in items) {
      final w = prefs.colors[i.color] ?? 0;
      colorScore += w;
      if (w > bestColorWeight) {
        bestColorWeight = w;
        bestColor = i.color;
      }
    }
    final formal = prefs.formality;
    final formalityFit = formal == null
        ? 0.0
        : 1 - (avgFormality - formal).abs();
    final score = colorScore + formalityFit * 2;

    final Why why;
    if (bestColor != null) {
      why = Why(WhyKind.favouriteColor, color: bestColor);
    } else if (formal != null) {
      why = Why(
        WhyKind.dressCode,
        level: (formal * (dressCodeLevels - 1)).round(),
      );
    } else {
      final goal = prefs.goals.entries
          .where((e) => e.value > 0)
          .map((e) => e.key)
          .firstOrNull;
      why = goal != null
          ? Why(WhyKind.goal, goal: goal)
          : const Why(WhyKind.versatile);
    }
    return Outfit(items: items, why: why, score: score);
  }
}
