import 'dart:typed_data';

import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/closet/domain/taxonomy.dart';

/// Dart twin of the API's `FakeVisionProvider`, used by mock mode so the app shows realistic results
/// with no server: taxonomy ids found in the file name (`navy_jeans_f2.jpg`) become confident answers,
/// everything else is derived from a hash of the image with low confidence.
class FakeVision {
  const FakeVision();

  static const _formality = {
    't_shirt': 2,
    'long_sleeve_tee': 2,
    'shirt': 3,
    'blouse': 3,
    'polo': 3,
    'sweater': 2,
    'hoodie': 1,
    'tank_top': 2,
    'crop_top': 2,
    'cardigan': 3,
    'bodysuit': 2,
    'jeans': 2,
    'trousers': 4,
    'chinos': 3,
    'shorts': 2,
    'joggers': 1,
    'leggings': 1,
    'skirt': 3,
    'jacket': 2,
    'blazer': 4,
    'suit_jacket': 5,
    'coat': 3,
    'puffer': 2,
    'denim_jacket': 2,
    'raincoat': 2,
    'vest': 3,
    'sneakers': 2,
    'boots': 3,
    'loafers': 4,
    'sandals': 2,
    'dress_shoes': 5,
    'heels': 4,
    'flats': 3,
    'casual_dress': 2,
    'cocktail_dress': 5,
    'maxi_dress': 3,
    'jumpsuit': 3,
    'hat': 2,
    'scarf': 3,
    'belt': 3,
    'tie': 5,
    'bag': 3,
    'jewelry': 4,
    'sunglasses': 2,
    'watch': 3,
  };
  static const _winter = {
    'coat',
    'puffer',
    'sweater',
    'hoodie',
    'boots',
    'scarf',
    'cardigan',
  };
  static const _summer = {
    'shorts',
    'tank_top',
    'sandals',
    'crop_top',
    'sunglasses',
    'maxi_dress',
  };
  static const _words = {
    'lounge': 1,
    'loungewear': 1,
    'casual': 2,
    'smart': 3,
    'business': 4,
    'formal': 5,
  };

  static String _tokens(String? name) =>
      '_${(name ?? '').toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '')}_';
  static bool _has(String toks, String id) => toks.contains('_${id}_');

  static int _hash(Uint8List bytes) {
    var h = 0x811c9dc5;
    for (var i = 0; i < bytes.length; i += bytes.length ~/ 512 + 1) {
      h = ((h ^ bytes[i]) * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  /// `{field: {value, confidence}}` exactly like the API returns.
  Map<String, Map<String, Object?>> analyse(
    String? filename,
    Uint8List bytes, {
    ClothingDepartment? department,
  }) {
    final tx = Taxonomy.instance;
    final toks = _tokens(filename);
    final n = _hash(bytes);
    if (_has(toks, 'fail')) {
      throw StateError('fake vision: permanent failure requested by file name');
    }

    String pick(List<String> o, int salt) => o[(n >> salt) % o.length];
    final subs = [
      for (final c in tx.categories)
        for (final s in c.subcategories) s.id,
    ];
    var sub = subs.where((s) => _has(toks, s)).firstOrNull;
    var category = tx.categoryIds.where((c) => _has(toks, c)).firstOrNull;
    final subNamed = sub != null;
    if (sub == null) {
      if (category != null) {
        sub = tx.subcategoriesOf(category).first.id;
      } else {
        final visible = <String>[
          for (final c in tx.categories)
            for (final s in c.subcategories)
              if (tx.subcategoryVisible(s.id, department)) s.id,
        ]..sort();
        sub = visible[n % visible.length];
      }
    }
    final catNamed = category != null;
    category = tx.categoryOf(sub);

    final colors = [
      for (final p in tx.palette) p.id,
    ].where((c) => _has(toks, c)).toList();
    final primary = colors.isNotEmpty
        ? colors.first
        : pick([for (final p in tx.palette) p.id], 8);
    final secondary = colors.length > 1 ? colors[1] : null;
    final patternNamed = tx.patterns
        .where((p) => p != 'solid' && _has(toks, p))
        .firstOrNull;

    var formality = _words.entries
        .where((e) => _has(toks, e.key))
        .map((e) => e.value)
        .firstOrNull;
    formality ??= [1, 2, 3, 4, 5].where((d) => _has(toks, 'f$d')).firstOrNull;
    final formalityConf = formality != null ? 0.9 : 0.62;
    formality ??= _formality[sub] ?? 3;

    final named = tx.seasons.where((s) => _has(toks, s)).toList();
    final List<String> seasons;
    if (named.isNotEmpty) {
      seasons = named;
    } else if (_winter.contains(sub)) {
      seasons = ['autumn', 'winter'];
    } else if (_summer.contains(sub)) {
      seasons = ['spring', 'summer'];
    } else {
      seasons = [...tx.seasons];
    }
    final fit = tx.fits.where((f) => _has(toks, f)).firstOrNull;
    final material = tx.materials.where((m) => _has(toks, m)).firstOrNull;

    Map<String, Object?> f(Object? v, double c) => {
      'value': v,
      'confidence': c,
    };
    final out = <String, Map<String, Object?>>{
      'category': f(category, subNamed ? 0.96 : (catNamed ? 0.9 : 0.55)),
      'subcategory': f(sub, subNamed ? 0.95 : (catNamed ? 0.6 : 0.5)),
      'primary_color': f(primary, colors.isNotEmpty ? 0.94 : 0.5),
      'secondary_color': f(secondary, secondary != null ? 0.85 : 0.8),
      'pattern': f(patternNamed ?? 'solid', patternNamed != null ? 0.9 : 0.8),
      'formality': f(formality, formalityConf),
      'seasons': f(seasons, named.isNotEmpty ? 0.88 : 0.6),
      'fit': f(fit, fit != null ? 0.8 : 0.4),
      'material': f(material, material != null ? 0.85 : 0.4),
    };
    if (_has(toks, 'lowconf')) {
      for (final v in out.values) {
        v['confidence'] = 0.5;
      }
    }
    return out;
  }
}
