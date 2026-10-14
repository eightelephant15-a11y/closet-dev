import 'package:flutter/foundation.dart';

enum ClosetSort {
  newest('created_desc'),
  oldest('created_asc'),
  recentlyEdited('updated_desc'),
  formalityLow('formality_asc'),
  formalityHigh('formality_desc')
  ;

  const ClosetSort(this.wire);
  final String wire;
}

enum ArchivedMode { exclude, only, include }

/// Everything the closet grid can filter, search and sort by. Maps 1:1 to `GET /v1/garments`.
@immutable
class ClosetQuery {
  const ClosetQuery({
    this.category,
    this.subcategory,
    this.color,
    this.season,
    this.formalityMin,
    this.formalityMax,
    this.text = '',
    this.favorite,
    this.availability,
    this.archived = ArchivedMode.exclude,
    this.reviewed,
    this.sort = ClosetSort.newest,
  });

  final String? category;
  final String? subcategory;
  final String? color;
  final String? season;
  final int? formalityMin;
  final int? formalityMax;
  final String text;
  final bool? favorite;
  final String? availability;
  final ArchivedMode archived;
  final bool? reviewed;
  final ClosetSort sort;

  /// Filters the user set (search text, sort and archive view not counted).
  int get activeFilterCount =>
      [
        category,
        subcategory,
        color,
        season,
        favorite,
        availability,
      ].where((e) => e != null).length +
      (formalityMin != null || formalityMax != null ? 1 : 0);

  bool get isDefault => this == const ClosetQuery();

  ClosetQuery copyWith({
    Object? category = _keep,
    Object? subcategory = _keep,
    Object? color = _keep,
    Object? season = _keep,
    Object? formalityMin = _keep,
    Object? formalityMax = _keep,
    String? text,
    Object? favorite = _keep,
    Object? availability = _keep,
    ArchivedMode? archived,
    Object? reviewed = _keep,
    ClosetSort? sort,
  }) {
    T? pick<T>(Object? v, T? current) =>
        identical(v, _keep) ? current : v as T?;
    return ClosetQuery(
      category: pick(category, this.category),
      subcategory: pick(subcategory, this.subcategory),
      color: pick(color, this.color),
      season: pick(season, this.season),
      formalityMin: pick(formalityMin, this.formalityMin),
      formalityMax: pick(formalityMax, this.formalityMax),
      text: text ?? this.text,
      favorite: pick(favorite, this.favorite),
      availability: pick(availability, this.availability),
      archived: archived ?? this.archived,
      reviewed: pick(reviewed, this.reviewed),
      sort: sort ?? this.sort,
    );
  }

  Map<String, String> toParams({
    int limit = 40,
    String? cursor,
    String thumb = 'm',
  }) => {
    'limit': '$limit',
    'thumb': thumb,
    'sort': sort.wire,
    'archived': archived.name,
    'category': ?category,
    'subcategory': ?subcategory,
    'color': ?color,
    'season': ?season,
    if (formalityMin != null) 'formality_min': '$formalityMin',
    if (formalityMax != null) 'formality_max': '$formalityMax',
    if (text.trim().isNotEmpty) 'q': text.trim(),
    if (favorite != null) 'favorite': '$favorite',
    'availability': ?availability,
    if (reviewed != null) 'reviewed': '$reviewed',
    'cursor': ?cursor,
  };

  @override
  bool operator ==(Object other) =>
      other is ClosetQuery &&
      category == other.category &&
      subcategory == other.subcategory &&
      color == other.color &&
      season == other.season &&
      formalityMin == other.formalityMin &&
      formalityMax == other.formalityMax &&
      text == other.text &&
      favorite == other.favorite &&
      availability == other.availability &&
      archived == other.archived &&
      reviewed == other.reviewed &&
      sort == other.sort;

  @override
  int get hashCode => Object.hash(
    category,
    subcategory,
    color,
    season,
    formalityMin,
    formalityMax,
    text,
    favorite,
    availability,
    archived,
    reviewed,
    sort,
  );
}

const Object _keep = Object();
