import 'package:freezed_annotation/freezed_annotation.dart';

part 'garment.freezed.dart';

enum AnalysisStatus {
  pending,
  processing,
  analysing,
  done,
  needsManual
  ;

  static AnalysisStatus parse(String s) => switch (s) {
    'processing' => processing,
    'analysing' => analysing,
    'done' => done,
    'needs_manual' => needsManual,
    _ => pending,
  };

  /// The photo is still being handled; details will appear on their own.
  bool get isWorking =>
      this == pending || this == processing || this == analysing;
}

enum Availability {
  available,
  laundry,
  lent,
  repair
  ;

  static Availability parse(String s) => Availability.values.firstWhere(
    (e) => e.name == s,
    orElse: () => available,
  );
}

enum ImageStatus {
  awaitingUpload,
  uploaded,
  processing,
  ready,
  failed
  ;

  static ImageStatus parse(String s) => switch (s) {
    'awaiting_upload' => awaitingUpload,
    'uploaded' => uploaded,
    'processing' => processing,
    'ready' => ready,
    _ => failed,
  };
}

/// One AI answer: the value and how sure the model was (0..1).
@immutable
class AiField {
  const AiField(this.value, this.confidence);
  final Object? value;
  final double confidence;

  @override
  bool operator ==(Object other) =>
      other is AiField &&
      other.value.toString() == value.toString() &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(value.toString(), confidence);
}

@freezed
abstract class GarmentImage with _$GarmentImage {
  const factory GarmentImage({
    required String id,
    required ImageStatus status,
    int? width,
    int? height,
    String? urlSmall,
    String? urlMedium,
    String? urlLarge,
    String? urlFull,
    String? error,
  }) = _GarmentImage;

  factory GarmentImage.fromApi(Map<String, dynamic> j) {
    final urls = (j['urls'] as Map?)?.cast<String, dynamic>() ?? const {};
    return GarmentImage(
      id: j['id'] as String,
      status: ImageStatus.parse(j['status'] as String),
      width: j['width'] as int?,
      height: j['height'] as int?,
      urlSmall: urls['s'] as String?,
      urlMedium: urls['m'] as String?,
      urlLarge: urls['l'] as String?,
      urlFull: urls['full'] as String?,
      error: j['error'] as String?,
    );
  }
}

/// Full garment, as shown on the review and detail screens.
@freezed
abstract class Garment with _$Garment {
  const factory Garment({
    required String id,
    required String clientId,
    required AnalysisStatus analysisStatus,
    required DateTime updatedAt,
    required DateTime createdAt,
    String? category,
    String? subcategory,
    String? primaryColor,
    String? secondaryColor,
    String? pattern,
    int? formality,
    List<String>? seasons,
    String? fit,
    String? material,
    String? brand,
    String? notes,
    @Default(false) bool favorite,
    @Default(Availability.available) Availability availability,
    DateTime? unavailableUntil,
    @Default(false) bool archived,
    @Default(false) bool reviewed,
    @Default(false) bool excludedFromOutfits,
    @Default(false) bool isSample,
    String? sampleAsset,
    Map<String, AiField>? aiFields,
    @Default(<String>[]) List<String> lowConfidenceFields,
    @Default(<GarmentImage>[]) List<GarmentImage> images,
    String? coverImageId,
  }) = _Garment;
  const Garment._();

  factory Garment.fromApi(Map<String, dynamic> j) {
    final analysis = (j['analysis'] as Map).cast<String, dynamic>();
    final fields = (analysis['fields'] as Map?)?.cast<String, dynamic>();
    return Garment(
      id: j['id'] as String,
      clientId: j['client_id'] as String,
      analysisStatus: AnalysisStatus.parse(analysis['status'] as String),
      createdAt: DateTime.parse(j['created_at'] as String),
      updatedAt: DateTime.parse(j['updated_at'] as String),
      category: j['category'] as String?,
      subcategory: j['subcategory'] as String?,
      primaryColor: j['primary_color'] as String?,
      secondaryColor: j['secondary_color'] as String?,
      pattern: j['pattern'] as String?,
      formality: j['formality'] as int?,
      seasons: (j['seasons'] as List?)?.cast<String>(),
      fit: j['fit'] as String?,
      material: j['material'] as String?,
      brand: j['brand'] as String?,
      notes: j['notes'] as String?,
      favorite: j['favorite'] as bool? ?? false,
      availability: Availability.parse(
        j['availability'] as String? ?? 'available',
      ),
      unavailableUntil: j['unavailable_until'] == null
          ? null
          : DateTime.parse(j['unavailable_until'] as String),
      archived: j['archived'] as bool? ?? false,
      reviewed: j['reviewed'] as bool? ?? false,
      excludedFromOutfits: j['excluded_from_outfits'] as bool? ?? false,
      isSample: j['is_sample'] as bool? ?? false,
      sampleAsset: j['sample_asset'] as String?,
      aiFields: fields?.map(
        (k, v) => MapEntry(
          k,
          AiField(
            (v as Map)['value'],
            ((v['confidence']) as num).toDouble(),
          ),
        ),
      ),
      lowConfidenceFields:
          ((analysis['low_confidence_fields'] as List?) ?? const [])
              .cast<String>(),
      images: [
        for (final i in (j['images'] as List? ?? const []))
          GarmentImage.fromApi((i as Map).cast<String, dynamic>()),
      ],
      coverImageId: j['cover_image_id'] as String?,
    );
  }

  GarmentImage? get cover {
    for (final i in images) {
      if (i.id == coverImageId) return i;
    }
    return images.isEmpty ? null : images.first;
  }

  /// True once the owner has everything the outfit engine needs.
  bool get hasCoreDetails =>
      category != null &&
      subcategory != null &&
      primaryColor != null &&
      pattern != null &&
      formality != null &&
      (seasons?.isNotEmpty ?? false);

  GarmentSummary toSummary() => GarmentSummary(
    id: id,
    category: category,
    subcategory: subcategory,
    primaryColor: primaryColor,
    secondaryColor: secondaryColor,
    pattern: pattern,
    formality: formality,
    seasons: seasons,
    favorite: favorite,
    availability: availability,
    archived: archived,
    reviewed: reviewed,
    excludedFromOutfits: excludedFromOutfits,
    analysisStatus: analysisStatus,
    lowConfidenceFields: lowConfidenceFields,
    isSample: isSample,
    sampleAsset: sampleAsset,
    thumbUrl: cover?.urlMedium,
    imageVersion: cover?.status == ImageStatus.ready ? cover!.id : null,
    updatedAt: updatedAt,
  );
}

/// Slim row for the grid and for filtering.
@freezed
abstract class GarmentSummary with _$GarmentSummary {
  const factory GarmentSummary({
    required String id,
    required AnalysisStatus analysisStatus,
    required DateTime updatedAt,
    String? category,
    String? subcategory,
    String? primaryColor,
    String? secondaryColor,
    String? pattern,
    int? formality,
    List<String>? seasons,
    @Default(false) bool favorite,
    @Default(Availability.available) Availability availability,
    @Default(false) bool archived,
    @Default(false) bool reviewed,
    @Default(false) bool excludedFromOutfits,
    @Default(<String>[]) List<String> lowConfidenceFields,
    @Default(false) bool isSample,
    String? sampleAsset,
    String? thumbUrl,
    String? imageVersion,
  }) = _GarmentSummary;
  const GarmentSummary._();

  factory GarmentSummary.fromApi(Map<String, dynamic> j) => GarmentSummary(
    id: j['id'] as String,
    analysisStatus: AnalysisStatus.parse(j['analysis_status'] as String),
    updatedAt: DateTime.parse(j['updated_at'] as String),
    category: j['category'] as String?,
    subcategory: j['subcategory'] as String?,
    primaryColor: j['primary_color'] as String?,
    secondaryColor: j['secondary_color'] as String?,
    pattern: j['pattern'] as String?,
    formality: j['formality'] as int?,
    seasons: (j['seasons'] as List?)?.cast<String>(),
    favorite: j['favorite'] as bool? ?? false,
    availability: Availability.parse(
      j['availability'] as String? ?? 'available',
    ),
    archived: j['archived'] as bool? ?? false,
    reviewed: j['reviewed'] as bool? ?? false,
    excludedFromOutfits: j['excluded_from_outfits'] as bool? ?? false,
    lowConfidenceFields: ((j['low_confidence_fields'] as List?) ?? const [])
        .cast<String>(),
    isSample: j['is_sample'] as bool? ?? false,
    sampleAsset: j['sample_asset'] as String?,
    thumbUrl: j['thumb_url'] as String?,
    imageVersion: j['image_version'] as String?,
  );
}

@immutable
class GarmentPage {
  const GarmentPage({
    required this.items,
    required this.total,
    this.nextCursor,
  });
  final List<GarmentSummary> items;
  final int total;
  final String? nextCursor;
}

@immutable
class ClosetSummary {
  const ClosetSummary({
    required this.total,
    required this.archived,
    required this.favorites,
    required this.needsReview,
    required this.counts,
    required this.availableCounts,
    required this.limit,
    required this.used,
  });

  factory ClosetSummary.fromApi(Map<String, dynamic> j) {
    CategoryCounts counts(Object? o) {
      final m = (o! as Map).cast<String, dynamic>();
      Map<String, int> ints(Object? x) => ((x as Map?) ?? const {}).map(
        (k, v) => MapEntry(k as String, v as int),
      );
      return CategoryCounts(ints(m['by_category']), ints(m['by_subcategory']));
    }

    return ClosetSummary(
      total: j['total'] as int,
      archived: j['archived'] as int,
      favorites: j['favorites'] as int,
      needsReview: j['needs_review'] as int,
      counts: counts(j['counts']),
      availableCounts: counts(j['available_counts']),
      limit: j['closet_item_limit'] as int,
      used: j['closet_items_used'] as int,
    );
  }

  static const empty = ClosetSummary(
    total: 0,
    archived: 0,
    favorites: 0,
    needsReview: 0,
    counts: CategoryCounts({}, {}),
    availableCounts: CategoryCounts({}, {}),
    limit: 30,
    used: 0,
  );

  final int total;
  final int archived;
  final int favorites;
  final int needsReview;
  final CategoryCounts counts;

  /// Items that could be worn today (not archived, not in the laundry / lent / repair).
  final CategoryCounts availableCounts;
  final int limit;
  final int used;

  int get remaining => (limit - used).clamp(0, limit);
}

@immutable
class CategoryCounts {
  const CategoryCounts(this.byCategory, this.bySubcategory);
  final Map<String, int> byCategory;
  final Map<String, int> bySubcategory;
  int category(String id) => byCategory[id] ?? 0;
}

/// Server-side limits for the current plan (Free: 30 items). Payments arrive in Phase 6.
@immutable
class Entitlements {
  const Entitlements({
    required this.plan,
    required this.limit,
    required this.used,
    required this.bulkEnabled,
    required this.bulkMax,
  });

  factory Entitlements.fromApi(Map<String, dynamic> j) => Entitlements(
    plan: j['plan'] as String,
    limit: j['closet_item_limit'] as int,
    used: j['closet_items_used'] as int,
    bulkEnabled: j['bulk_add_enabled'] as bool,
    bulkMax: j['bulk_max'] as int,
  );

  final String plan;
  final int limit;
  final int used;
  final bool bulkEnabled;
  final int bulkMax;
  int get remaining => (limit - used).clamp(0, limit);
}

/// What the app needs to upload one photo.
@immutable
class UploadTicket {
  const UploadTicket({
    required this.imageId,
    required this.url,
    required this.method,
    required this.headers,
    required this.fields,
    required this.expiresAt,
    required this.maxBytes,
  });

  factory UploadTicket.fromApi(Map<String, dynamic> j) => UploadTicket(
    imageId: j['image_id'] as String,
    url: j['url'] as String,
    method: j['method'] as String,
    headers: ((j['headers'] as Map?) ?? const {}).cast<String, String>(),
    fields: ((j['fields'] as Map?) ?? const {}).cast<String, String>(),
    expiresAt: DateTime.fromMillisecondsSinceEpoch(
      (j['expires_at'] as int) * 1000,
      isUtc: true,
    ),
    maxBytes: j['max_bytes'] as int,
  );

  final String imageId;
  final String url;
  final String method;
  final Map<String, String> headers;
  final Map<String, String> fields;
  final DateTime expiresAt;
  final int maxBytes;

  bool isExpired([DateTime? now]) => (now ?? DateTime.now().toUtc()).isAfter(
    expiresAt.subtract(const Duration(seconds: 30)),
  );
}

@immutable
class CreatedGarment {
  const CreatedGarment(this.garment, this.ticket);
  final Garment garment;
  final UploadTicket? ticket;
}
