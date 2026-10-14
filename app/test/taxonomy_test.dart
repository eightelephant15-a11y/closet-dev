import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/closet/domain/taxonomy.dart';
import 'package:stylist/features/closet/domain/taxonomy_data.dart';
import 'package:stylist/features/closet/domain/taxonomy_labels.dart';
import 'package:stylist/features/onboarding/domain/quiz.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';

void main() {
  final tx = Taxonomy.instance;

  test('generated Dart data equals the single source of truth', () {
    final source = jsonDecode(
      File('../taxonomy/garment_taxonomy.v1.json').readAsStringSync(),
    );
    expect(
      jsonDecode(taxonomyJson),
      source,
      reason: 'run: python3 tool/gen_taxonomy.py',
    );
  });

  test('parses the structure', () {
    expect(tx.version, 1);
    expect(tx.categoryIds, [
      'top',
      'bottom',
      'outerwear',
      'footwear',
      'dress',
      'accessory',
    ]);
    expect(tx.categoryOf('jeans'), 'bottom');
    expect(tx.categoryOf('nope'), isNull);
    expect(tx.formality, [1, 2, 3, 4, 5]);
    expect(tx.seasons, ['spring', 'summer', 'autumn', 'winter']);
    expect(tx.colorById('navy')!.color.toARGB32(), 0xFF1B2A55);
    expect(tx.aiFields, contains('primary_color'));
  });

  test('every id has a localised label (generated ARB keys)', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    for (final c in tx.categories) {
      expect(l10n.taxCategory(c.id), isNot(c.id), reason: c.id);
      for (final s in c.subcategories) {
        expect(l10n.taxSubcategory(s.id), isNot(s.id), reason: s.id);
      }
    }
    for (final p in tx.palette) {
      expect(l10n.taxColor(p.id), isNot(p.id), reason: p.id);
    }
    for (final id in tx.patterns) {
      expect(l10n.taxPattern(id), isNot(id), reason: id);
    }
    for (final id in tx.seasons) {
      expect(l10n.taxSeason(id), isNot(id), reason: id);
    }
    for (final id in tx.fits) {
      expect(l10n.taxFit(id), isNot(id), reason: id);
    }
    for (final id in tx.materials) {
      expect(l10n.taxMaterial(id), isNot(id), reason: id);
    }
    for (final v in tx.formality) {
      expect(l10n.taxFormalityLabel(v), isNot('$v'), reason: '$v');
    }
    expect(l10n.taxSubcategory('t_shirt'), 'T-shirt');
    expect(l10n.taxColor('light_blue'), 'Light blue');
  });

  group('department filtering', () {
    test('menswear hides womenswear-only items and the dress category', () {
      expect(tx.subcategoryVisible('tie', ClothingDepartment.menswear), isTrue);
      expect(
        tx.subcategoryVisible('heels', ClothingDepartment.menswear),
        isFalse,
      );
      expect(
        tx.subcategoryVisible('skirt', ClothingDepartment.menswear),
        isFalse,
      );
      expect(
        tx.visibleCategories(ClothingDepartment.menswear).map((c) => c.id),
        isNot(contains('dress')),
      );
    });

    test('womenswear hides men-only items', () {
      expect(
        tx.subcategoryVisible('tie', ClothingDepartment.womenswear),
        isFalse,
      );
      expect(
        tx.subcategoryVisible('heels', ClothingDepartment.womenswear),
        isTrue,
      );
      expect(
        tx.visibleCategories(ClothingDepartment.womenswear).map((c) => c.id),
        contains('dress'),
      );
    });

    test('both / everything / unknown show everything', () {
      for (final d in [
        ClothingDepartment.both,
        ClothingDepartment.everything,
        null,
      ]) {
        expect(tx.subcategoryVisible('tie', d), isTrue);
        expect(tx.subcategoryVisible('heels', d), isTrue);
        expect(tx.visibleCategories(d), hasLength(6));
      }
    });
  });

  group('quiz "never wear" mapping comes from the taxonomy', () {
    bool avoided(
      Set<NeverWear> a, {
      String? category,
      String? sub,
      String? color,
    }) => tx.isAvoided(
      avoid: a,
      category: category,
      subcategory: sub,
      primaryColor: color,
    );

    test('subcategory groups', () {
      expect(avoided({NeverWear.heels}, sub: 'heels'), isTrue);
      expect(avoided({NeverWear.heels}, sub: 'sneakers'), isFalse);
      expect(avoided({NeverWear.sleeveless}, sub: 'tank_top'), isTrue);
      expect(avoided({NeverWear.cropTops}, sub: 'crop_top'), isTrue);
      expect(avoided({NeverWear.suits}, sub: 'blazer'), isTrue);
      expect(avoided({NeverWear.suits}, sub: 'suit_jacket'), isTrue);
      expect(
        avoided({NeverWear.shorts, NeverWear.skirts}, sub: 'skirt'),
        isTrue,
      );
      expect(avoided({NeverWear.ties, NeverWear.hats}, sub: 'hat'), isTrue);
    });

    test('whole-category and colour groups', () {
      expect(
        avoided({NeverWear.dresses}, category: 'dress', sub: 'maxi_dress'),
        isTrue,
      );
      expect(avoided({NeverWear.brightColors}, color: 'red'), isTrue);
      expect(avoided({NeverWear.brightColors}, color: 'navy'), isFalse);
      expect(avoided({NeverWear.brightColors}), isFalse);
    });

    test('every quiz never-wear option has a taxonomy group', () {
      const probes = {
        NeverWear.sleeveless: (null, 'tank_top', null),
        NeverWear.shorts: (null, 'shorts', null),
        NeverWear.heels: (null, 'heels', null),
        NeverWear.skirts: (null, 'skirt', null),
        NeverWear.dresses: ('dress', null, null),
        NeverWear.cropTops: (null, 'crop_top', null),
        NeverWear.suits: (null, 'blazer', null),
        NeverWear.ties: (null, 'tie', null),
        NeverWear.hats: (null, 'hat', null),
        NeverWear.brightColors: (null, null, 'red'),
      };
      expect(probes.keys.toSet(), NeverWear.values.toSet());
      for (final e in probes.entries) {
        expect(
          tx.isAvoided(
            avoid: {e.key},
            category: e.value.$1,
            subcategory: e.value.$2,
            primaryColor: e.value.$3,
          ),
          isTrue,
          reason: neverWearWire(e.key),
        );
      }
    });

    test('nothing avoided by default', () {
      expect(avoided({}, sub: 'heels', color: 'red'), isFalse);
    });
  });
}
