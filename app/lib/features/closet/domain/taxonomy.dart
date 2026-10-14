import 'dart:convert';
import 'dart:ui' show Color;

import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/closet/domain/taxonomy_data.dart';
import 'package:stylist/features/onboarding/domain/quiz.dart';

/// Typed access to the garment taxonomy (`taxonomy/garment_taxonomy.v1.json`, generated into
/// `taxonomy_data.dart`). The app, the API and the AI prompt all read the same document: never
/// hard-code a category, colour or season name elsewhere.
class Subcategory {
  const Subcategory({
    required this.id,
    required this.categoryId,
    required this.departments,
  });
  final String id;
  final String categoryId;

  /// `clothing_department` values that see this subcategory (`menswear`, `womenswear`).
  final Set<String> departments;
}

class TaxonomyCategory {
  const TaxonomyCategory({required this.id, required this.subcategories});
  final String id;
  final List<Subcategory> subcategories;
}

class PaletteColor {
  const PaletteColor({
    required this.id,
    required this.color,
    required this.bright,
  });
  final String id;
  final Color color;
  final bool bright;
}

class Taxonomy {
  Taxonomy._({
    required this.version,
    required this.categories,
    required this.palette,
    required this.patterns,
    required this.seasons,
    required this.fits,
    required this.materials,
    required this.formality,
    required this.aiFields,
    required this.brandMax,
    required this.notesMax,
    required Map<String, Map<String, Set<String>>> avoidGroups,
  }) : _avoid = avoidGroups,
       _subToCategory = {
         for (final c in categories)
           for (final s in c.subcategories) s.id: c.id,
       },
       _subById = {
         for (final c in categories)
           for (final s in c.subcategories) s.id: s,
       };

  factory Taxonomy.parse(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    List<String> ids(String key) => [
      for (final e in j[key] as List)
        (e as Map<String, dynamic>)['id'] as String,
    ];
    final avoid = <String, Map<String, Set<String>>>{};
    (j['avoid_groups'] as Map<String, dynamic>).forEach((k, v) {
      final m = v as Map<String, dynamic>;
      avoid[k] = {
        'subcategories': {
          ...((m['subcategories'] as List?) ?? const []).cast<String>(),
        },
        'categories': {
          ...((m['categories'] as List?) ?? const []).cast<String>(),
        },
        'bright': {if (m['bright_palette'] == true) 'yes'},
      };
    });
    return Taxonomy._(
      version: j['version'] as int,
      categories: [
        for (final c in j['categories'] as List)
          TaxonomyCategory(
            id: (c as Map<String, dynamic>)['id'] as String,
            subcategories: [
              for (final s in c['subcategories'] as List)
                Subcategory(
                  id: (s as Map<String, dynamic>)['id'] as String,
                  categoryId: c['id'] as String,
                  departments: {...(s['departments'] as List).cast<String>()},
                ),
            ],
          ),
      ],
      palette: [
        for (final p in j['palette'] as List)
          PaletteColor(
            id: (p as Map<String, dynamic>)['id'] as String,
            color: Color(
              0xFF000000 |
                  int.parse((p['hex'] as String).substring(1), radix: 16),
            ),
            bright: p['bright'] as bool,
          ),
      ],
      patterns: ids('patterns'),
      seasons: ids('seasons'),
      fits: ids('fits'),
      materials: ids('materials'),
      formality: [
        for (final f in j['formality'] as List)
          (f as Map<String, dynamic>)['value'] as int,
      ],
      aiFields: (j['ai_fields'] as List).cast<String>(),
      brandMax: (j['limits'] as Map<String, dynamic>)['brand_max'] as int,
      notesMax: (j['limits'] as Map<String, dynamic>)['notes_max'] as int,
      avoidGroups: avoid,
    );
  }

  static final Taxonomy instance = Taxonomy.parse(taxonomyJson);

  final int version;
  final List<TaxonomyCategory> categories;
  final List<PaletteColor> palette;
  final List<String> patterns;
  final List<String> seasons;
  final List<String> fits;
  final List<String> materials;
  final List<int> formality;
  final List<String> aiFields;
  final int brandMax;
  final int notesMax;
  final Map<String, Map<String, Set<String>>> _avoid;
  final Map<String, String> _subToCategory;
  final Map<String, Subcategory> _subById;

  List<String> get categoryIds => [for (final c in categories) c.id];

  String? categoryOf(String subcategory) => _subToCategory[subcategory];

  List<Subcategory> subcategoriesOf(String category) =>
      categories.firstWhere((c) => c.id == category).subcategories;

  PaletteColor? colorById(String id) {
    for (final p in palette) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool isBright(String? colorId) =>
      colorId != null && (colorById(colorId)?.bright ?? false);

  /// Whether the user's `clothing_department` shows this subcategory.
  bool subcategoryVisible(String subcategory, ClothingDepartment? department) {
    final s = _subById[subcategory];
    if (s == null) return false;
    return switch (department) {
      ClothingDepartment.menswear => s.departments.contains('menswear'),
      ClothingDepartment.womenswear => s.departments.contains('womenswear'),
      _ => true,
    };
  }

  List<TaxonomyCategory> visibleCategories(ClothingDepartment? department) => [
    for (final c in categories)
      if (c.subcategories.any((s) => subcategoryVisible(s.id, department))) c,
  ];

  List<Subcategory> visibleSubcategories(
    String category,
    ClothingDepartment? department,
  ) => [
    for (final s in subcategoriesOf(category))
      if (subcategoryVisible(s.id, department)) s,
  ];

  /// True if a garment falls under one of the user's quiz "never wear" choices.
  bool isAvoided({
    required Set<NeverWear> avoid,
    required String? category,
    required String? subcategory,
    required String? primaryColor,
  }) {
    for (final n in avoid) {
      final g = _avoid[neverWearWire(n)];
      if (g == null) continue;
      if (subcategory != null && g['subcategories']!.contains(subcategory)) {
        return true;
      }
      if (category != null && g['categories']!.contains(category)) return true;
      if (g['bright']!.isNotEmpty && isBright(primaryColor)) return true;
    }
    return false;
  }
}
