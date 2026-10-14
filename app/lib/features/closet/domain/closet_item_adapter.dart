import 'package:stylist/features/closet/data/sample_garments.dart';
import 'package:stylist/features/closet/domain/closet_item.dart';
import 'package:stylist/features/closet/domain/garment.dart';
import 'package:stylist/features/closet/domain/taxonomy.dart';
import 'package:stylist/features/onboarding/domain/quiz.dart';

/// Bridges the real closet (taxonomy v1) to the Phase 1 recommendation seam, which still works with
/// [ClosetItem]. Phase 3 replaces the seam and this file with it.
ClosetItem? closetItemFromParts({
  required String id,
  required String? category,
  required String? subcategory,
  required String? primaryColor,
  required int? formality,
}) {
  if (category == null || primaryColor == null) {
    return null;
  }
  final tax = Taxonomy.instance;
  final mapped = switch (category) {
    'top' => ItemCategory.top,
    'bottom' => ItemCategory.bottom,
    'footwear' => ItemCategory.shoes,
    'dress' => ItemCategory.dress,
    'outerwear' => ItemCategory.outerwear,
    _ => null, // accessories do not make a base outfit
  };
  if (mapped == null) {
    return null;
  }
  final color = _color(primaryColor);
  final sub = subcategory == null
      ? null
      : tax
            .subcategoriesOf(category)
            .where((s) => s.id == subcategory)
            .firstOrNull;
  final dept = sub == null || sub.departments.length == 2
      ? ItemDepartment.unisex
      : sub.departments.contains('menswear')
      ? ItemDepartment.menswear
      : ItemDepartment.womenswear;
  final tags = [
    for (final n in NeverWear.values)
      if (tax.isAvoided(
        avoid: {n},
        category: category,
        subcategory: subcategory,
        primaryColor: primaryColor,
      ))
        neverWearWire(n),
  ];
  return ClosetItem(
    id: id,
    name: subcategory ?? category,
    category: mapped,
    color: color,
    formality: ((formality ?? 3) - 1) / 4,
    department: dept,
    tags: tags,
    subcategory: subcategory,
    colorId: primaryColor,
  );
}

/// Palette colours the Phase 1 model does not have fall back to their nearest relative.
ClothingColor _color(String id) => switch (id) {
  'light_blue' => ClothingColor.blue,
  'teal' => ClothingColor.green,
  'burgundy' => ClothingColor.red,
  'cream' => ClothingColor.beige,
  _ => ClothingColor.values.firstWhere(
    (c) => c.name == id,
    orElse: () => ClothingColor.grey,
  ),
};

/// A wearable garment as a recommendation input; null for anything that cannot be worn today.
ClosetItem? closetItemFromSummary(GarmentSummary g) {
  if (g.archived || g.excludedFromOutfits) {
    return null;
  }
  return closetItemFromParts(
    id: g.id,
    category: g.category,
    subcategory: g.subcategory,
    primaryColor: g.primaryColor,
    formality: g.formality,
  );
}

/// The bundled sample closet, as recommendation input (unit tests and docs).
List<ClosetItem> closetItemsFromSample() => [
  for (final s in sampleGarments)
    ?closetItemFromParts(
      id: s.asset,
      category: s.category,
      subcategory: s.subcategory,
      primaryColor: s.primaryColor,
      formality: s.formality,
    ),
];
