import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:stylist/core/network/api_client.dart';
import 'package:stylist/core/network/api_exception.dart';
import 'package:stylist/features/closet/domain/closet_query.dart';
import 'package:stylist/features/closet/domain/garment.dart';
import 'package:stylist/features/closet/domain/garment_repository.dart';

typedef Json = Map<String, dynamic>;

class HttpGarmentRepository implements GarmentRepository {
  HttpGarmentRepository(this._dio);
  final Dio _dio;

  Future<Json> _json(Future<Response<Json>> Function() call) async =>
      (await guarded(call)).data!;

  @override
  Future<ClosetSummary> summary() async => ClosetSummary.fromApi(
    await _json(() => _dio.get<Json>('/v1/garments/summary')),
  );

  @override
  Future<Entitlements> entitlements() async => Entitlements.fromApi(
    await _json(() => _dio.get<Json>('/v1/entitlements')),
  );

  @override
  Future<GarmentPage> list(
    ClosetQuery query, {
    String? cursor,
    int limit = 40,
  }) async {
    final j = await _json(
      () => _dio.get<Json>(
        '/v1/garments',
        queryParameters: query.toParams(limit: limit, cursor: cursor),
      ),
    );
    return GarmentPage(
      items: [
        for (final i in j['items'] as List)
          GarmentSummary.fromApi((i as Map).cast<String, dynamic>()),
      ],
      total: j['total'] as int,
      nextCursor: j['next_cursor'] as String?,
    );
  }

  @override
  Future<Garment> get(String id) async =>
      Garment.fromApi(await _json(() => _dio.get<Json>('/v1/garments/$id')));

  Json _body(NewGarment n) => {
    'client_id': n.clientId,
    'content_type': n.contentType,
    if (n.filename != null) 'filename': n.filename,
    if (n.sizeBytes != null) 'size_bytes': n.sizeBytes,
  };

  CreatedGarment _created(Json j) => CreatedGarment(
    Garment.fromApi(j),
    j['upload'] == null
        ? null
        : UploadTicket.fromApi((j['upload'] as Map).cast<String, dynamic>()),
  );

  @override
  Future<CreatedGarment> create(NewGarment item) async => _created(
    await _json(() => _dio.post<Json>('/v1/garments', data: _body(item))),
  );

  @override
  Future<List<CreatedGarment>> bulkCreate(List<NewGarment> items) async {
    final j = await _json(
      () => _dio.post<Json>(
        '/v1/garments/bulk',
        data: {'items': items.map(_body).toList()},
      ),
    );
    return [
      for (final i in j['items'] as List)
        _created((i as Map).cast<String, dynamic>()),
    ];
  }

  @override
  Future<UploadTicket> newTicket(String garmentId, String imageId) async =>
      UploadTicket.fromApi(
        await _json(
          () => _dio.post<Json>(
            '/v1/garments/$garmentId/images/$imageId/upload-url',
          ),
        ),
      );

  @override
  Future<Garment> complete(String garmentId, String imageId) async =>
      Garment.fromApi(
        await _json(
          () => _dio.post<Json>(
            '/v1/garments/$garmentId/images/$imageId/complete',
          ),
        ),
      );

  @override
  Future<Garment> patch(String id, Map<String, Object?> changes) async =>
      Garment.fromApi(
        await _json(() => _dio.patch<Json>('/v1/garments/$id', data: changes)),
      );

  @override
  Future<void> delete(String id) =>
      guarded(() => _dio.delete<void>('/v1/garments/$id'));

  @override
  Future<Garment> reanalyse(String id) async => Garment.fromApi(
    await _json(() => _dio.post<Json>('/v1/garments/$id/reanalyse')),
  );

  @override
  Future<List<Garment>> seedSample() async {
    final res = await guarded(
      () => _dio.post<List<dynamic>>('/v1/garments/sample'),
    );
    return [
      for (final g in res.data!)
        Garment.fromApi((g as Map).cast<String, dynamic>()),
    ];
  }
}

/// Direct-to-storage upload. A plain Dio (no auth header, no base URL): the signed URL is the credential.
class DioUploadTransport implements UploadTransport {
  DioUploadTransport([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(minutes: 2),
            ),
          );
  final Dio _dio;

  @override
  Future<void> upload(
    UploadTicket ticket,
    Uint8List bytes, {
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      if (ticket.method == 'PUT') {
        await _dio.put<void>(
          ticket.url,
          data: Stream.fromIterable([bytes]),
          options: Options(
            headers: {
              ...ticket.headers,
              Headers.contentLengthHeader: bytes.length,
            },
          ),
          onSendProgress: onProgress,
        );
      } else {
        // S3 presigned POST: form fields first, the file last.
        final form = FormData.fromMap({
          ...ticket.fields,
          'file': MultipartFile.fromBytes(bytes, filename: 'photo'),
        });
        await _dio.post<void>(
          ticket.url,
          data: form,
          onSendProgress: onProgress,
        );
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 403) throw const UploadTicketExpired();
      if (code == 413) {
        throw const ApiException(
          code: 'file_too_large',
          message: 'Photo too large',
          statusCode: 413,
        );
      }
      if (code == 415) {
        throw const ApiException(
          code: 'unsupported_media',
          message: 'Unsupported photo',
          statusCode: 415,
        );
      }
      if (e.response == null) throw const ApiException.offline();
      throw ApiException(
        code: 'upload_failed',
        message: e.message ?? '',
        statusCode: code,
      );
    }
  }
}
