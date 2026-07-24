import 'package:dio/dio.dart';

/// 서버 공통 응답 envelope(`{success, data, error{code,message}}`)의
/// `error`를 그대로 옮긴 예외. 화면은 이 `code`로 분기한다.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
  });

  final String code;
  final String message;
  final int? statusCode;

  /// `error` 객체에 함께 실려 온 부가 필드(예: OUT_OF_RADIUS의 현재 거리).
  final Map<String, dynamic>? details;

  static const networkError = 'NETWORK_ERROR';
  static const unknownError = 'UNKNOWN_ERROR';

  /// dio 예외·envelope 본문 등 무엇이 오든 하나의 [ApiException]으로 정규화한다.
  factory ApiException.from(Object error) {
    if (error is ApiException) return error;

    if (error is DioException) {
      final wrapped = error.error;
      if (wrapped is ApiException) return wrapped;

      final parsed = ApiException.tryParse(
        error.response?.data,
        error.response?.statusCode,
      );
      if (parsed != null) return parsed;

      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError => const ApiException(
          code: networkError,
          message: '서버에 연결하지 못했어요.',
        ),
        _ => ApiException(
          code: unknownError,
          message: error.message ?? '알 수 없는 오류가 발생했어요.',
          statusCode: error.response?.statusCode,
        ),
      };
    }

    return ApiException(code: unknownError, message: error.toString());
  }

  /// envelope 본문에서 `error`를 읽어 예외로 변환한다. 실패 형식이 아니면 null.
  static ApiException? tryParse(Object? body, int? statusCode) {
    if (body is! Map) return null;
    final error = body['error'];
    if (error is! Map) return null;

    return ApiException(
      code: (error['code'] as String?) ?? unknownError,
      message: (error['message'] as String?) ?? '',
      statusCode: statusCode,
      details: Map<String, dynamic>.from(error)
        ..remove('code')
        ..remove('message'),
    );
  }

  @override
  String toString() => 'ApiException($code, $message)';
}
