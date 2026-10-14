/// The guest sample closet (mirrors `api/app/data/sample_closet.py`). Pictures are bundled with the app
/// under `assets/sample_closet/<asset>.webp`; sample garments never upload anything.
const _all = ['spring', 'summer', 'autumn', 'winter'];

class SampleGarment {
  const SampleGarment(
    this.asset,
    this.category,
    this.subcategory,
    this.primaryColor,
    this.formality,
    this.seasons,
  );
  final String asset;
  final String category;
  final String subcategory;
  final String primaryColor;
  final int formality;
  final List<String> seasons;
}

const sampleGarments = <SampleGarment>[
  SampleGarment('sample_white_shirt', 'top', 'shirt', 'white', 3, _all),
  SampleGarment('sample_navy_sweater', 'top', 'sweater', 'navy', 2, [
    'autumn',
    'winter',
  ]),
  SampleGarment('sample_grey_tee', 'top', 't_shirt', 'grey', 1, [
    'spring',
    'summer',
  ]),
  SampleGarment('sample_black_tank', 'top', 'tank_top', 'black', 3, ['summer']),
  SampleGarment('sample_olive_overshirt', 'top', 'shirt', 'olive', 2, [
    'spring',
    'autumn',
  ]),
  SampleGarment('sample_red_crop', 'top', 'crop_top', 'red', 2, ['summer']),
  SampleGarment('sample_indigo_jeans', 'bottom', 'jeans', 'navy', 2, _all),
  SampleGarment('sample_beige_chinos', 'bottom', 'chinos', 'beige', 3, [
    'spring',
    'summer',
    'autumn',
  ]),
  SampleGarment(
    'sample_black_trousers',
    'bottom',
    'trousers',
    'black',
    4,
    _all,
  ),
  SampleGarment('sample_khaki_shorts', 'bottom', 'shorts', 'beige', 1, [
    'summer',
  ]),
  SampleGarment('sample_brown_skirt', 'bottom', 'skirt', 'brown', 3, [
    'spring',
    'autumn',
  ]),
  SampleGarment(
    'sample_white_sneakers',
    'footwear',
    'sneakers',
    'white',
    2,
    _all,
  ),
  SampleGarment(
    'sample_brown_loafers',
    'footwear',
    'loafers',
    'brown',
    4,
    _all,
  ),
  SampleGarment('sample_black_heels', 'footwear', 'heels', 'black', 4, _all),
  SampleGarment('sample_green_dress', 'dress', 'casual_dress', 'green', 3, [
    'spring',
    'summer',
  ]),
  SampleGarment('sample_navy_blazer', 'outerwear', 'blazer', 'navy', 4, [
    'spring',
    'autumn',
    'winter',
  ]),
];
