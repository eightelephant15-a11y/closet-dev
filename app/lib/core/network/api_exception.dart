/// Mirrors the API error model `{code, message, details}`.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
  });

  /// Network failure (no response).
  const ApiException.offline()
    : code = 'offline',
      message = 'No connection',
      statusCode = null,
      details = null;

  final String code;
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;

  bool get isOffline => code == 'offline';

  @override
  String toString() => 'ApiException($code: $message)';
}
