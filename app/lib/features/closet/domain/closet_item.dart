import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/onboarding/domain/quiz.dart';

enum ItemCategory { top, bottom, shoes, dress, outerwear }

enum ItemDepartment { menswear, womenswear, unisex }

class ClosetItem {
  const ClosetItem({
    required this.id,
    required this.name,
    required this.category,
    required this.color,
    required this.formality,
    required this.department,
    this.tags = const [],
    this.subcategory,
    this.colorId,
  });

  factory ClosetItem.fromJson(Map<String, dynamic> j) => ClosetItem(
    id: j['id'] as String,
    name: j['name'] as String,
    category: ItemCategory.values.byName(j['category'] as String),
    color: ClothingColor.values.byName(j['color'] as String),
    formality: (j['formality'] as num).toDouble(),
    department: ItemDepartment.values.byName(j['dept'] as String),
    tags: ((j['tags'] as List?) ?? const []).cast<String>(),
    subcategory: j['subcategory'] as String?,
    colorId: j['color_id'] as String?,
  );

  final String id;
  final String name;
  final ItemCategory category;
  final ClothingColor color;

  /// 0 = very casual ... 1 = formal.
  final double formality;
  final ItemDepartment department;

  /// Matches never-wear wire names (e.g. `heels`, `skirts`).
  final List<String> tags;

  /// Taxonomy ids, for showing a localised name ("Navy jeans").
  final String? subcategory;
  final String? colorId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'color': color.name,
    'formality': formality,
    'dept': department.name,
    'tags': tags,
    'subcategory': subcategory,
    'color_id': colorId,
  };

  /// Whether this item belongs in the user's chosen department.
  bool fitsDepartment(ClothingDepartment? d) => switch (d) {
    ClothingDepartment.menswear => department != ItemDepartment.womenswear,
    ClothingDepartment.womenswear => department != ItemDepartment.menswear,
    _ => true,
  };

  /// True if the user said they never wear this kind of item.
  bool isBlockedBy(Set<NeverWear> blocked) =>
      blocked.any((n) => tags.contains(neverWearWire(n)));
}
