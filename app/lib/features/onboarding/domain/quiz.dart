import 'package:stylist/features/auth/domain/app_user.dart';

enum Fit { relaxed, regular, slim }

enum Goal { work, dates, travel, everyday }

/// 0 = very casual ... 4 = formal.
const dressCodeLevels = 5;

enum ClothingColor {
  black,
  white,
  grey,
  navy,
  beige,
  brown,
  olive,
  red,
  pink,
  blue,
  green,
  yellow,
  purple,
  orange,
}

const Set<ClothingColor> brightColors = {
  ClothingColor.red,
  ClothingColor.pink,
  ClothingColor.yellow,
  ClothingColor.orange,
  ClothingColor.green,
  ClothingColor.purple,
};

enum NeverWear {
  sleeveless,
  shorts,
  brightColors,
  suits,
  ties,
  hats,
  heels,
  skirts,
  dresses,
  cropTops,
}

/// Never-wear choices adapted to the department (mirrors the API).
List<NeverWear> neverWearOptions(ClothingDepartment? department) {
  const common = [
    NeverWear.sleeveless,
    NeverWear.shorts,
    NeverWear.brightColors,
  ];
  const men = [...common, NeverWear.suits, NeverWear.ties, NeverWear.hats];
  const women = [
    ...common,
    NeverWear.heels,
    NeverWear.skirts,
    NeverWear.dresses,
    NeverWear.cropTops,
  ];
  return switch (department) {
    ClothingDepartment.menswear => men,
    ClothingDepartment.womenswear => women,
    _ => {...men, ...women}.toList(),
  };
}

/// Wire name for API payloads (snake_case).
String neverWearWire(NeverWear n) => switch (n) {
  NeverWear.brightColors => 'bright_colors',
  NeverWear.cropTops => 'crop_tops',
  _ => n.name,
};

enum QuizQuestion { department, fit, colors, neverWear, dressCode, goals }

class QuizAnswers {
  const QuizAnswers({
    this.department,
    this.fit,
    this.colors = const {},
    this.neverWear,
    this.dressCode,
    this.goals,
  });

  factory QuizAnswers.fromJson(Map<String, dynamic> j) => QuizAnswers(
    department: j['department'] == null
        ? null
        : ClothingDepartment.values.byName(j['department'] as String),
    fit: j['fit'] == null ? null : Fit.values.byName(j['fit'] as String),
    colors: {
      for (final c in (j['colors'] as List?) ?? const <dynamic>[])
        ClothingColor.values.byName(c as String),
    },
    neverWear: j['never_wear'] == null
        ? null
        : {
            for (final n in j['never_wear'] as List)
              NeverWear.values.firstWhere((v) => neverWearWire(v) == n),
          },
    dressCode: j['dress_code'] as int?,
    goals: j['goals'] == null
        ? null
        : {for (final g in j['goals'] as List) Goal.values.byName(g as String)},
  );

  final ClothingDepartment? department;
  final Fit? fit;
  final Set<ClothingColor> colors;

  /// null = unanswered; empty = "nothing, I wear it all".
  final Set<NeverWear>? neverWear;
  final int? dressCode;
  final Set<Goal>? goals;

  bool isAnswered(QuizQuestion q) => switch (q) {
    QuizQuestion.department => department != null,
    QuizQuestion.fit => fit != null,
    QuizQuestion.colors => colors.isNotEmpty,
    QuizQuestion.neverWear => neverWear != null,
    QuizQuestion.dressCode => dressCode != null,
    QuizQuestion.goals => goals != null && goals!.isNotEmpty,
  };

  bool get isComplete => QuizQuestion.values.every(isAnswered);

  QuizAnswers copyWith({
    ClothingDepartment? department,
    Fit? fit,
    Set<ClothingColor>? colors,
    Set<NeverWear>? neverWear,
    int? dressCode,
    Set<Goal>? goals,
  }) {
    // Changing department invalidates never-wear choices not offered any more.
    final newDept = department ?? this.department;
    var nw = neverWear ?? this.neverWear;
    if (nw != null && department != null) {
      nw = nw.intersection(neverWearOptions(newDept).toSet());
    }
    return QuizAnswers(
      department: newDept,
      fit: fit ?? this.fit,
      colors: colors ?? this.colors,
      neverWear: nw,
      dressCode: dressCode ?? this.dressCode,
      goals: goals ?? this.goals,
    );
  }

  /// API payload for `PUT /v1/me/preferences` (only answered questions).
  Map<String, dynamic> toJson() => {
    if (department != null) 'department': department!.name,
    if (fit != null) 'fit': fit!.name,
    if (colors.isNotEmpty) 'colors': colors.map((c) => c.name).toList()..sort(),
    if (neverWear != null)
      'never_wear': neverWear!.map(neverWearWire).toList()..sort(),
    if (dressCode != null) 'dress_code': dressCode,
    if (goals != null) 'goals': goals!.map((g) => g.name).toList()..sort(),
  };
}
