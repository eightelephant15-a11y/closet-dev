import 'package:flutter/foundation.dart';

/// How many wearable garments the closet has per outfit slot. Archived and unavailable items are not
/// counted by the caller (they cannot be worn today).
@immutable
class SlotCounts {
  const SlotCounts({
    this.tops = 0,
    this.bottoms = 0,
    this.footwear = 0,
    this.dresses = 0,
    this.outerwear = 0,
    this.accessories = 0,
  });

  /// Counts by taxonomy category id (`top`, `bottom`, `footwear`, `dress`, `outerwear`, `accessory`).
  factory SlotCounts.fromCategoryCounts(Map<String, int> byCategory) =>
      SlotCounts(
        tops: byCategory['top'] ?? 0,
        bottoms: byCategory['bottom'] ?? 0,
        footwear: byCategory['footwear'] ?? 0,
        dresses: byCategory['dress'] ?? 0,
        outerwear: byCategory['outerwear'] ?? 0,
        accessories: byCategory['accessory'] ?? 0,
      );

  final int tops;
  final int bottoms;
  final int footwear;
  final int dresses;
  final int outerwear;
  final int accessories;

  int get total =>
      tops + bottoms + footwear + dresses + outerwear + accessories;

  /// Distinct base outfits: top + bottom + shoes, or dress + shoes. Layers and accessories do not
  /// create new base outfits, so they never count here.
  int get outfitCount => tops * bottoms * footwear + dresses * footwear;

  SlotCounts plusOne(String category) => SlotCounts(
    tops: tops + (category == 'top' ? 1 : 0),
    bottoms: bottoms + (category == 'bottom' ? 1 : 0),
    footwear: footwear + (category == 'footwear' ? 1 : 0),
    dresses: dresses + (category == 'dress' ? 1 : 0),
    outerwear: outerwear + (category == 'outerwear' ? 1 : 0),
    accessories: accessories + (category == 'accessory' ? 1 : 0),
  );

  @override
  bool operator ==(Object other) =>
      other is SlotCounts &&
      tops == other.tops &&
      bottoms == other.bottoms &&
      footwear == other.footwear &&
      dresses == other.dresses &&
      outerwear == other.outerwear &&
      accessories == other.accessories;

  @override
  int get hashCode =>
      Object.hash(tops, bottoms, footwear, dresses, outerwear, accessories);
}

enum MeterLevel { empty, starting, growing, rich }

/// "Add a pair of shoes: it unlocks 6 more outfits."
@immutable
class MeterNudge {
  const MeterNudge({
    required this.category,
    required this.outfitsBefore,
    required this.outfitsAfter,
  });
  final String category;
  final int outfitsBefore;
  final int outfitsAfter;

  int get gain => outfitsAfter - outfitsBefore;
}

@immutable
class ClosetMeter {
  const ClosetMeter({
    required this.outfits,
    required this.level,
    required this.progress,
    this.nudge,
  });

  factory ClosetMeter.of(SlotCounts c) {
    final outfits = c.outfitCount;
    final level = outfits >= richAt
        ? MeterLevel.rich
        : outfits >= growingAt
        ? MeterLevel.growing
        : outfits >= startingAt
        ? MeterLevel.starting
        : MeterLevel.empty;
    return ClosetMeter(
      outfits: outfits,
      level: level,
      progress: (outfits / fullAt).clamp(0.0, 1.0),
      nudge: _nudge(c, outfits),
    );
  }

  /// Outfit counts at which the level changes.
  static const startingAt = 1;
  static const growingAt = 10;
  static const richAt = 50;

  /// The meter is full here; beyond it more items still help but the bar stays full.
  static const fullAt = 60;

  final int outfits;
  final MeterLevel level;

  /// 0..1 for the bar.
  final double progress;

  /// Null when no single new item would increase the number of possible outfits (so we say nothing
  /// rather than nag).
  final MeterNudge? nudge;

  /// Picks the single category whose next item adds the most outfits. Ties go to the earlier slot in
  /// [_slots] (the most basic gap first). Returns null if nothing would add an outfit.
  static MeterNudge? _nudge(SlotCounts c, int before) {
    MeterNudge? best;
    for (final slot in _slots) {
      final after = c.plusOne(slot).outfitCount;
      if (after > before && (best == null || after - before > best.gain)) {
        best = MeterNudge(
          category: slot,
          outfitsBefore: before,
          outfitsAfter: after,
        );
      }
    }
    return best;
  }

  static const _slots = ['footwear', 'top', 'bottom', 'dress'];
}
