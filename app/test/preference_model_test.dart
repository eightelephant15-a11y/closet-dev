import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/onboarding/domain/preference_model.dart';
import 'package:stylist/features/onboarding/domain/quiz.dart';

void main() {
  const base = QuizAnswers(
    department: ClothingDepartment.womenswear,
    fit: Fit.regular,
    colors: {ClothingColor.navy},
    neverWear: <NeverWear>{},
    dressCode: 2,
    goals: {Goal.work},
  );

  test('fit answer changes fit weights', () {
    final relaxed = PreferenceModel.fromAnswers(
      base.copyWith(fit: Fit.relaxed),
    );
    final slim = PreferenceModel.fromAnswers(base.copyWith(fit: Fit.slim));
    expect(relaxed.fit[Fit.relaxed], 1.0);
    expect(relaxed.fit[Fit.slim], 0.0);
    expect(slim.fit[Fit.slim], 1.0);
    expect(slim.fit[Fit.relaxed], 0.0);
  });

  test('favourite colours weigh 1, bright never-wear overrides to -1', () {
    final m = PreferenceModel.fromAnswers(
      base.copyWith(colors: {ClothingColor.navy, ClothingColor.red}),
    );
    expect(m.colors[ClothingColor.red], 1.0);
    final m2 = PreferenceModel.fromAnswers(
      base.copyWith(
        colors: {ClothingColor.navy, ClothingColor.red},
        neverWear: {NeverWear.brightColors},
      ),
    );
    expect(m2.colors[ClothingColor.red], -1.0);
    expect(m2.colors[ClothingColor.navy], 1.0);
    expect(m2.blocked, isEmpty);
  });

  test('never-wear items block categories; dress code scales formality', () {
    final m = PreferenceModel.fromAnswers(
      base.copyWith(
        neverWear: {NeverWear.heels, NeverWear.skirts},
        dressCode: 4,
      ),
    );
    expect(m.blocked, {NeverWear.heels, NeverWear.skirts});
    expect(m.formality, 1.0);
    expect(
      PreferenceModel.fromAnswers(base.copyWith(dressCode: 0)).formality,
      0.0,
    );
  });

  test('goals map to weights; empty answers are neutral', () {
    expect(PreferenceModel.fromAnswers(base).goals[Goal.work], 1.0);
    expect(PreferenceModel.fromAnswers(base).goals[Goal.travel], 0.0);
    final empty = PreferenceModel.fromAnswers(const QuizAnswers());
    expect(empty.formality, isNull);
    expect(empty.fit.values.every((v) => v == 0), isTrue);
  });

  test('never-wear options adapt to department', () {
    expect(
      neverWearOptions(ClothingDepartment.womenswear),
      contains(NeverWear.heels),
    );
    expect(
      neverWearOptions(ClothingDepartment.menswear),
      isNot(contains(NeverWear.heels)),
    );
    expect(
      neverWearOptions(ClothingDepartment.menswear),
      contains(NeverWear.ties),
    );
    expect(
      neverWearOptions(ClothingDepartment.both),
      containsAll([NeverWear.heels, NeverWear.ties]),
    );
  });

  test('switching department drops now-invalid never-wear choices', () {
    final a = base.copyWith(neverWear: {NeverWear.heels, NeverWear.shorts});
    final men = a.copyWith(department: ClothingDepartment.menswear);
    expect(men.neverWear, {NeverWear.shorts});
  });

  test('answers round-trip through the API payload', () {
    final json = base.copyWith(neverWear: {NeverWear.cropTops}).toJson();
    expect(json['never_wear'], ['crop_tops']);
    final back = QuizAnswers.fromJson(json);
    expect(back.neverWear, {NeverWear.cropTops});
    expect(back.department, ClothingDepartment.womenswear);
    expect(back.isComplete, isTrue);
  });
}
