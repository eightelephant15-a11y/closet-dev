import 'package:dio/dio.dart';
import 'package:stylist/core/network/api_exception.dart';
import 'package:uuid/uuid.dart';

typedef TokenGetter = Future<String?> Function({bool forceRefresh});

/// Dio wrapper: bearer token (with one refresh-and-retry on 401), request ids,
/// idempotency keys for mutating calls, and mapping to [ApiException].
Dio buildDio({
  required String baseUrl,
  required TokenGetter getToken,
  required String deviceId,
  required void Function() onSessionRevoked,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  const uuid = Uuid();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        options.headers['X-Device-Id'] = deviceId;
        options.headers['X-Request-ID'] = uuid.v4().replaceAll('-', '');
        if (const {'POST', 'PUT', 'PATCH', 'DELETE'}.contains(options.method)) {
          options.headers.putIfAbsent('Idempotency-Key', uuid.v4);
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        final status = e.response?.statusCode;
        final retried = e.requestOptions.extra['retried'] == true;
        if (status == 401 && !retried) {
          final data = e.response?.data;
          final err = data is Map ? data['error'] : null;
          final code = err is Map ? err['code'] : null;
          if (code == 'session_revoked') {
            onSessionRevoked();
          } else {
            final token = await getToken(forceRefresh: true);
            if (token != null) {
              final req = e.requestOptions
                ..extra['retried'] = true
                ..headers['Authorization'] = 'Bearer $token';
              try {
                return handler.resolve(await dio.fetch<dynamic>(req));
              } on DioException catch (e2) {
                return handler.next(e2);
              }
            }
          }
        }
        handler.next(e);
      },
    ),
  );
  return dio;
}

ApiException mapDioError(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['error'] is Map) {
    final err = data['error'] as Map;
    return ApiException(
      code: err['code'] as String? ?? 'unknown',
      message: err['message'] as String? ?? '',
      statusCode: e.response?.statusCode,
      details: (err['details'] as Map?)?.cast<String, dynamic>(),
    );
  }
  if (e.response == null) return const ApiException.offline();
  return ApiException(
    code: 'http_${e.response!.statusCode}',
    message: e.message ?? '',
    statusCode: e.response!.statusCode,
  );
}

/// Runs [body] and converts [DioException] to [ApiException].
Future<T> guarded<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on DioException catch (e) {
    throw mapDioError(e);
  }
}
