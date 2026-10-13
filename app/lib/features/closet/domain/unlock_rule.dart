import 'package:stylist/features/closet/domain/closet_item.dart';

/// Target shown by the "Add your first 10 items" ring.
const firstItemsTarget = 10;

class UnlockProgress {
  const UnlockProgress({
    required this.tops,
    required this.bottoms,
    required this.shoes,
    required this.dresses,
    required this.total,
  });

  factory UnlockProgress.of(Iterable<ClosetItem> items) {
    var tops = 0;
    var bottoms = 0;
    var shoes = 0;
    var dresses = 0;
    var total = 0;
    for (final i in items) {
      total++;
      switch (i.category) {
        case ItemCategory.top:
          tops++;
        case ItemCategory.bottom:
          bottoms++;
        case ItemCategory.shoes:
          shoes++;
        case ItemCategory.dress:
          dresses++;
        case ItemCategory.outerwear:
          break;
      }
    }
    return UnlockProgress(
      tops: tops,
      bottoms: bottoms,
      shoes: shoes,
      dresses: dresses,
      total: total,
    );
  }

  final int tops;
  final int bottoms;
  final int shoes;
  final int dresses;
  final int total;

  /// Unlock rule: 2 tops + 2 bottoms + 1 pair of shoes, or 1 dress + shoes.
  bool get isUnlocked =>
      shoes >= 1 && ((tops >= 2 && bottoms >= 2) || dresses >= 1);

  double get ringProgress => (total / firstItemsTarget).clamp(0, 1).toDouble();
}
