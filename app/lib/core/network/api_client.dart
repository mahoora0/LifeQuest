import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:life_quest/core/auth/token_storage.dart';
import 'package:life_quest/core/config/app_config.dart';
import 'package:life_quest/core/network/api_exception.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(const FlutterSecureStorage());
});

final dioProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);

  final dio = Dio(_baseOptions());

  // 재발급 전용 클라이언트 — 인터셉터가 없어 401 재귀를 만들지 않는다.
  final reissueDio = Dio(_baseOptions());

  // 401 재시도 전용 클라이언트 — 토큰 부착과 envelope 해제만 수행한다.
  final retryDio = Dio(_baseOptions())
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          await _attachToken(options, tokenStorage);
          handler.next(options);
        },
        onResponse: _unwrapEnvelope,
      ),
    );

  dio.interceptors.add(
    _AuthInterceptor(
      tokenStorage: tokenStorage,
      reissueDio: reissueDio,
      retryDio: retryDio,
    ),
  );

  ref.onDispose(() {
    dio.close();
    reissueDio.close();
    retryDio.close();
  });

  return dio;
});

BaseOptions _baseOptions() => BaseOptions(
  baseUrl: AppConfig.apiBaseUrl,
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 10),
  headers: const {'Content-Type': 'application/json'},
);

Future<void> _attachToken(
  RequestOptions options,
  TokenStorage tokenStorage,
) async {
  final accessToken = await tokenStorage.readAccessToken();
  if (accessToken != null && accessToken.isNotEmpty) {
    options.headers['Authorization'] = 'Bearer $accessToken';
  }
}

/// 성공 envelope의 `data`만 남기고, `success=false`면 [ApiException]으로 거절한다.
void _unwrapEnvelope(
  Response<dynamic> response,
  ResponseInterceptorHandler handler,
) {
  final body = response.data;
  if (body is Map && body.containsKey('success')) {
    if (body['success'] == true) {
      response.data = body['data'];
      handler.next(response);
      return;
    }
    handler.reject(
      DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error:
            ApiException.tryParse(body, response.statusCode) ??
            const ApiException(
              code: ApiException.unknownError,
              message: '알 수 없는 오류가 발생했어요.',
            ),
      ),
      true,
    );
    return;
  }
  handler.next(response);
}

/// 토큰 부착 · envelope 해제 · 401 시 1회 재발급 후 재시도.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor({
    required this.tokenStorage,
    required this.reissueDio,
    required this.retryDio,
  });

  static const _retriedFlag = 'lq.retried';

  final TokenStorage tokenStorage;
  final Dio reissueDio;
  final Dio retryDio;

  /// 동시 401이 여러 건 나도 재발급은 한 번만 수행한다.
  Future<bool>? _inFlightReissue;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await _attachToken(options, tokenStorage);
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _unwrapEnvelope(response, handler);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final failure = ApiException.from(err);
    final alreadyRetried = err.requestOptions.extra[_retriedFlag] == true;
    final isAuthFailure =
        err.response?.statusCode == 401 ||
        failure.code == 'TOKEN_EXPIRED' ||
        failure.code == 'UNAUTHORIZED';

    if (isAuthFailure && !alreadyRetried) {
      final reissued = await _reissueOnce();
      if (reissued) {
        final options = err.requestOptions
          ..extra[_retriedFlag] = true
          ..headers.remove('Authorization');
        try {
          handler.resolve(await retryDio.fetch<dynamic>(options));
          return;
        } on DioException catch (retryError) {
          handler.reject(
            retryError.copyWith(error: ApiException.from(retryError)),
          );
          return;
        }
      }
    }

    handler.reject(err.copyWith(error: failure));
  }

  Future<bool> _reissueOnce() {
    return _inFlightReissue ??= _reissue()
      ..whenComplete(() => _inFlightReissue = null);
  }

  Future<bool> _reissue() async {
    final refreshToken = await tokenStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await reissueDio.post<dynamic>(
        '/auth/reissue',
        data: {'refreshToken': refreshToken},
      );
      final body = response.data;
      final data = (body is Map && body.containsKey('data'))
          ? body['data']
          : body;
      if (data is! Map) return false;

      final accessToken = data['accessToken'] as String?;
      if (accessToken == null || accessToken.isEmpty) return false;
      await tokenStorage.writeAccessToken(accessToken);

      final newRefreshToken = data['refreshToken'] as String?;
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await tokenStorage.writeRefreshToken(newRefreshToken);
      }
      return true;
    } on DioException {
      return false;
    }
  }
}
