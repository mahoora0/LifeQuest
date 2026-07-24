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
    // 보안 저장소 읽기는 키스토어 초기화·앱 서명 변경 시 PlatformException을
    // 던진다. 여기서 예외가 빠져나가면 handler가 호출되지 않아 요청 Future가
    // 영원히 완료되지 않으므로(앱 전체 정지), 반드시 삼키고 진행한다.
    try {
      await _attachToken(options, tokenStorage);
    } catch (_) {
      // 토큰을 붙이지 못하면 401로 이어지고, 그건 onError가 처리한다.
    }
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

    // onRequest와 같은 이유로 전체를 감싼다. 여기서 예외가 새어 나가면
    // handler가 호출되지 않아 해당 요청이 영원히 매달린다.
    try {
      if (isAuthFailure && !alreadyRetried) {
        final reissued = await _reissueOnce();
        if (reissued) {
          final options = err.requestOptions
            ..extra[_retriedFlag] = true
            ..headers.remove('Authorization');
          handler.resolve(await retryDio.fetch<dynamic>(options));
          return;
        }

        // 재발급이 실패했다 = 리프레시 토큰도 죽었다.
        // 죽은 토큰을 남겨 두면 이후 모든 요청이 401 → 재발급 실패를 무한
        // 반복하므로 여기서 지운다. 화면 전환은 각 화면이 TOKEN_EXPIRED
        // 문구를 보고 처리한다(인터셉터는 BuildContext를 갖지 않는다).
        await _clearTokensQuietly();
      }
    } on DioException catch (retryError) {
      handler.reject(retryError.copyWith(error: ApiException.from(retryError)));
      return;
    } catch (_) {
      // 저장소·플랫폼 오류 — 원래 오류로 떨어뜨려 요청을 끝낸다.
    }

    handler.reject(err.copyWith(error: failure));
  }

  Future<bool> _reissueOnce() {
    return _inFlightReissue ??= _reissue()
      ..whenComplete(() => _inFlightReissue = null);
  }

  /// 재발급은 어떤 이유로 실패하든 false를 돌려준다.
  /// 여기서 예외를 던지면 공유 중인 in-flight future를 통해
  /// 대기 중인 모든 요청으로 퍼지고, 처리되지 않은 zone 오류가 된다.
  Future<bool> _reissue() async {
    try {
      final refreshToken = await tokenStorage.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;

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
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearTokensQuietly() async {
    try {
      await tokenStorage.clear();
    } catch (_) {
      // 지우지 못해도 원래 오류 전달을 막지 않는다.
    }
  }
}
