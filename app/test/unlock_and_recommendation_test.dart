import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/closet/domain/closet_item.dart';
import 'package:stylist/features/closet/domain/closet_item_adapter.dart';
import 'package:stylist/features/closet/domain/unlock_rule.dart';
import 'package:stylist/features/onboarding/domain/preference_model.dart';
import 'package:stylist/features/onboarding/domain/quiz.dart';
import 'package:stylist/features/recommendation/domain/recommendation.dart';

ClosetItem item(
  String id,
  ItemCategory c, {
  ClothingColor color = ClothingColor.black,
  List<String> tags = const [],
}) => ClosetItem(
  id: id,
  name: id,
  category: c,
  color: color,
  formality: 0.5,
  department: ItemDepartment.unisex,
  tags: tags,
);

void main() {
  group('unlock rule', () {
    test('2 tops + 2 bottoms + shoes unlocks', () {
      final p = UnlockProgress.of([
        item('t1', ItemCategory.top),
        item('t2', ItemCategory.top),
        item('b1', ItemCategory.bottom),
        item('b2', ItemCategory.bottom),
        item('s1', ItemCategory.shoes),
      ]);
      expect(p.isUnlocked, isTrue);
    });

    test('1 dress + shoes unlocks', () {
      expect(
        UnlockProgress.of([
          item('d', ItemCategory.dress),
          item('s', ItemCategory.shoes),
        ]).isUnlocked,
        isTrue,
      );
    });

    test('does not unlock without shoes, or with too few pieces', () {
      expect(
        UnlockProgress.of([item('d', ItemCategory.dress)]).isUnlocked,
        isFalse,
      );
      expect(
        UnlockProgress.of([
          item('t1', ItemCategory.top),
          item('b1', ItemCategory.bottom),
          item('b2', ItemCategory.bottom),
          item('s', ItemCategory.shoes),
        ]).isUnlocked,
        isFalse,
      );
      expect(UnlockProgress.of([]).isUnlocked, isFalse);
    });

    test('ring caps at 10 items', () {
      final many = [for (var i = 0; i < 14; i++) item('i$i', ItemCategory.top)];
      expect(UnlockProgress.of(many).ringProgress, 1.0);
      expect(UnlockProgress.of(many.take(5)).ringProgress, 0.5);
    });
  });

  group('fake recommendation service', () {
    final service = FakeRecommendationService();
    const women = QuizAnswers(
      department: ClothingDepartment.womenswear,
      fit: Fit.regular,
      colors: {ClothingColor.navy},
      neverWear: <NeverWear>{},
      dressCode: 2,
      goals: {Goal.work},
    );

    Future<FirstOutfits?> run(QuizAnswers a) => service.firstOutfits(
      prefs: PreferenceModel.fromAnswers(a),
      answers: a,
      closet: closetItemsFromSample(),
    );

    test(
      'returns one outfit plus two distinct alternatives with why lines',
      () async {
        final r = (await run(women))!;
        expect(r.alternatives, hasLength(2));
        final sets = [
          r.primary,
          ...r.alternatives,
        ].map((o) => o.items.map((i) => i.id).toSet()).toList();
        expect(sets.toSet(), hasLength(3));
        expect(r.primary.why.kind, WhyKind.favouriteColor);
        expect(r.primary.why.color, ClothingColor.navy);
      },
    );

    test('never-wear items and other departments are excluded', () async {
      final men = women.copyWith(
        department: ClothingDepartment.menswear,
        neverWear: {NeverWear.shorts},
      );
      final r = (await run(men))!;
      for (final o in [r.primary, ...r.alternatives]) {
        for (final i in o.items) {
          expect(i.department, isNot(ItemDepartment.womenswear));
          expect(i.tags, isNot(contains('shorts')));
        }
      }
      final noHeels = women.copyWith(
        neverWear: {NeverWear.heels, NeverWear.dresses},
      );
      final r2 = (await run(noHeels))!;
      for (final o in [r2.primary, ...r2.alternatives]) {
        expect(
          o.items.any(
            (i) => i.tags.contains('heels') || i.tags.contains('dresses'),
          ),
          isFalse,
        );
      }
    });

    test('answers change the recommendation', () async {
      final formal = (await run(women.copyWith(dressCode: 4)))!;
      final casual = (await run(women.copyWith(dressCode: 0)))!;
      final f = formal.primary.items.map((i) => i.id).toSet();
      final c = casual.primary.items.map((i) => i.id).toSet();
      expect(f, isNot(equals(c)));
    });

    test('is deterministic', () async {
      final a = (await run(women))!.primary.items.map((i) => i.id).toList();
      final b = (await run(women))!.primary.items.map((i) => i.id).toList();
      expect(a, b);
    });

    test('returns null when the closet cannot form an outfit', () async {
      final r = await service.firstOutfits(
        prefs: PreferenceModel.fromAnswers(women),
        answers: women,
        closet: [item('t', ItemCategory.top)],
      );
      expect(r, isNull);
    });
  });
}
