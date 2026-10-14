import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/features/closet/domain/closet_meter.dart';

void main() {
  group('outfit count', () {
    test('empty closet has none', () {
      expect(const SlotCounts().outfitCount, 0);
    });

    test('tops x bottoms x shoes plus dresses x shoes', () {
      expect(
        const SlotCounts(tops: 3, bottoms: 2, footwear: 2).outfitCount,
        12,
      );
      expect(const SlotCounts(dresses: 2, footwear: 3).outfitCount, 6);
      expect(
        const SlotCounts(
          tops: 2,
          bottoms: 2,
          footwear: 1,
          dresses: 1,
        ).outfitCount,
        5,
      );
    });

    test('no shoes means no outfits', () {
      expect(const SlotCounts(tops: 5, bottoms: 5, dresses: 3).outfitCount, 0);
    });

    test('layers and accessories add no base outfits', () {
      const base = SlotCounts(tops: 2, bottoms: 2, footwear: 1);
      const more = SlotCounts(
        tops: 2,
        bottoms: 2,
        footwear: 1,
        outerwear: 4,
        accessories: 9,
      );
      expect(more.outfitCount, base.outfitCount);
    });

    test('built from taxonomy category counts', () {
      final c = SlotCounts.fromCategoryCounts(const {
        'top': 2,
        'bottom': 3,
        'footwear': 1,
        'accessory': 4,
        'unknown': 9,
      });
      expect(c.outfitCount, 6);
      expect(c.accessories, 4);
    });
  });

  group('levels and progress', () {
    test('boundaries', () {
      expect(ClosetMeter.of(const SlotCounts()).level, MeterLevel.empty);
      expect(
        ClosetMeter.of(
          const SlotCounts(tops: 1, bottoms: 1, footwear: 1),
        ).level,
        MeterLevel.starting,
      );
      expect(
        ClosetMeter.of(
          const SlotCounts(tops: 5, bottoms: 2, footwear: 1),
        ).level,
        MeterLevel.growing,
      );
      expect(
        ClosetMeter.of(
          const SlotCounts(tops: 5, bottoms: 5, footwear: 2),
        ).level,
        MeterLevel.rich,
      );
    });

    test('progress is clamped to 0..1', () {
      expect(ClosetMeter.of(const SlotCounts()).progress, 0);
      expect(
        ClosetMeter.of(
          const SlotCounts(tops: 20, bottoms: 20, footwear: 20),
        ).progress,
        1,
      );
    });
  });

  group('nudge', () {
    test(
      'suggests shoes first when there are none, since they unlock outfits',
      () {
        final m = ClosetMeter.of(const SlotCounts(tops: 3, bottoms: 3));
        expect(m.nudge!.category, 'footwear');
        expect(m.nudge!.outfitsBefore, 0);
        expect(m.nudge!.outfitsAfter, 9);
        expect(m.nudge!.gain, 9);
      },
    );

    test('suggests the slot that adds the most outfits', () {
      // A bottom adds 4 x 2 = 8; shoes add 4 x 1 = 4; a top adds 1 x 2 = 2.
      final m = ClosetMeter.of(
        const SlotCounts(tops: 4, bottoms: 1, footwear: 2),
      );
      expect(m.nudge!.category, 'bottom');
      expect(m.nudge!.gain, 8);
    });

    test(
      'an empty closet has nothing to nudge: no single item makes an outfit',
      () {
        expect(ClosetMeter.of(const SlotCounts()).nudge, isNull);
      },
    );

    test('never nudges when no new item would add an outfit', () {
      // Only outerwear and accessories: any single top/bottom/shoe/dress still adds zero outfits.
      expect(
        ClosetMeter.of(const SlotCounts(outerwear: 3, accessories: 3)).nudge,
        isNull,
      );
    });

    test('the nudge always strictly increases the outfit count', () {
      for (var t = 0; t < 4; t++) {
        for (var b = 0; b < 4; b++) {
          for (var f = 0; f < 4; f++) {
            for (var d = 0; d < 3; d++) {
              final c = SlotCounts(
                tops: t,
                bottoms: b,
                footwear: f,
                dresses: d,
              );
              final n = ClosetMeter.of(c).nudge;
              if (n != null) {
                expect(
                  c.plusOne(n.category).outfitCount,
                  greaterThan(c.outfitCount),
                );
                expect(n.outfitsAfter, c.plusOne(n.category).outfitCount);
              }
            }
          }
        }
      }
    });
  });
}
