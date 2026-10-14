import 'package:flutter/foundation.dart';
import 'package:stylist/features/closet/domain/closet_query.dart';
import 'package:stylist/features/closet/domain/garment.dart';

@immutable
class NewGarment {
  const NewGarment({
    required this.clientId,
    required this.contentType,
    this.filename,
    this.sizeBytes,
  });
  final String clientId;
  final String contentType;
  final String? filename;
  final int? sizeBytes;
}

/// The closet API (`/v1/garments*`). `HttpGarmentRepository` talks to the server, `MockClosetBackend`
/// reproduces its behaviour locally so the whole flow works with no cloud.
abstract class GarmentRepository {
  Future<ClosetSummary> summary();
  Future<Entitlements> entitlements();
  Future<GarmentPage> list(ClosetQuery query, {String? cursor, int limit = 40});
  Future<Garment> get(String id);

  /// Idempotent on `clientId`: a retry returns the same garment.
  Future<CreatedGarment> create(NewGarment item);
  Future<List<CreatedGarment>> bulkCreate(List<NewGarment> items);
  Future<UploadTicket> newTicket(String garmentId, String imageId);
  Future<Garment> complete(String garmentId, String imageId);

  /// Partial update (snake_case API field names). `null` values clear optional fields.
  Future<Garment> patch(String id, Map<String, Object?> changes);
  Future<void> delete(String id);
  Future<Garment> reanalyse(String id);
  Future<List<Garment>> seedSample();
}

/// Sends the photo bytes straight to object storage using a signed ticket (never through `/v1`).
abstract class UploadTransport {
  Future<void> upload(
    UploadTicket ticket,
    Uint8List bytes, {
    void Function(int sent, int total)? onProgress,
  });
}

/// The signed URL expired (403): ask the API for a new ticket and try again.
class UploadTicketExpired implements Exception {
  const UploadTicketExpired();
}
