import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/onboarding/domain/quiz.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';

extension QuizLabels on AppLocalizations {
  String question(QuizQuestion q) => switch (q) {
    QuizQuestion.department => quizQDepartment,
    QuizQuestion.fit => quizQFit,
    QuizQuestion.colors => quizQColors,
    QuizQuestion.neverWear => quizQNeverWear,
    QuizQuestion.dressCode => quizQDressCode,
    QuizQuestion.goals => quizQGoals,
  };

  String department(ClothingDepartment d) => switch (d) {
    ClothingDepartment.menswear => deptMenswear,
    ClothingDepartment.womenswear => deptWomenswear,
    ClothingDepartment.both => deptBoth,
    ClothingDepartment.everything => deptEverything,
  };

  String fit(Fit f) => switch (f) {
    Fit.relaxed => fitRelaxed,
    Fit.regular => fitRegular,
    Fit.slim => fitSlim,
  };

  String dressCode(int level) => switch (level) {
    0 => dressCode0,
    1 => dressCode1,
    2 => dressCode2,
    3 => dressCode3,
    _ => dressCode4,
  };

  String goal(Goal g) => switch (g) {
    Goal.work => goalWork,
    Goal.dates => goalDates,
    Goal.travel => goalTravel,
    Goal.everyday => goalEveryday,
  };

  String color(ClothingColor c) => switch (c) {
    ClothingColor.black => colorBlack,
    ClothingColor.white => colorWhite,
    ClothingColor.grey => colorGrey,
    ClothingColor.navy => colorNavy,
    ClothingColor.beige => colorBeige,
    ClothingColor.brown => colorBrown,
    ClothingColor.olive => colorOlive,
    ClothingColor.red => colorRed,
    ClothingColor.pink => colorPink,
    ClothingColor.blue => colorBlue,
    ClothingColor.green => colorGreen,
    ClothingColor.yellow => colorYellow,
    ClothingColor.purple => colorPurple,
    ClothingColor.orange => colorOrange,
  };

  String neverWear(NeverWear n) => switch (n) {
    NeverWear.sleeveless => neverSleeveless,
    NeverWear.shorts => neverShorts,
    NeverWear.brightColors => neverBrightColors,
    NeverWear.suits => neverSuits,
    NeverWear.ties => neverTies,
    NeverWear.hats => neverHats,
    NeverWear.heels => neverHeels,
    NeverWear.skirts => neverSkirts,
    NeverWear.dresses => neverDresses,
    NeverWear.cropTops => neverCropTops,
  };
}
