import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/core/location/location_service.dart';
import 'package:life_quest/core/network/provider_retry.dart';

/// provider 재시도 정책. **`null`을 돌려주면 즉시 실패로 확정**되고, `Duration`을
/// 돌려주면 그만큼 뒤에 다시 부른다.
///
/// 이 판정이 틀리면 화면이 조용히 망가진다 — 재시도가 도는 동안 상태는 계속
/// `AsyncLoading`이라 오류도 안내도 뜨지 않고, Riverpod 3 기본값으로는 그 대기가
/// **40초 가까이** 간다. 사용자에게는 그냥 멈춘 화면이다.
void main() {
  group('다시 시도해도 소용없는 실패는 즉시 확정한다', () {
    /// 권한 거부·GPS 꺼짐·fix 실패. 몇 초 뒤 다시 물어도 같은 답이 오고,
    /// 사용자가 설정을 바꿔야 풀린다.
    ///
    /// 상태 코드가 없어서 4xx 규칙에 걸리지 않는다 — 따로 가르지 않으면 지도가
    /// 오류 안내 대신 로딩만 돌았다(실제로 그랬다).
    test('위치 실패', () {
      expect(
        lqProviderRetry(0, const LocationServiceException('위치 권한이 필요합니다.')),
        isNull,
      );
    });

    test('4xx — 없는 엔드포인트·리소스·만료된 토큰', () {
      for (final status in [400, 401, 403, 404, 422, 499]) {
        expect(
          lqProviderRetry(0, _apiError(status)),
          isNull,
          reason: '$status는 같은 요청을 다시 보내도 결과가 달라지지 않는다',
        );
      }
    });
  });

  group('잠시 뒤 성공할 수 있는 실패는 기본 정책에 맡긴다', () {
    test('5xx', () {
      expect(lqProviderRetry(0, _apiError(500)), isNotNull);
      expect(lqProviderRetry(0, _apiError(503)), isNotNull);
    });

    /// 연결 실패는 상태 코드가 없다. 위치 실패와 같은 모양이라 **타입으로 갈라야**
    /// 하는 이유가 여기 있다 — 상태 코드만 보면 둘을 구분할 수 없다.
    test('연결 실패(상태 코드 없음)', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/quests/today'),
        type: DioExceptionType.connectionTimeout,
      );

      expect(lqProviderRetry(0, error), isNotNull);
    });
  });
}

DioException _apiError(int status) {
  final options = RequestOptions(path: '/quests/nearby');
  return DioException(
    requestOptions: options,
    response: Response<dynamic>(requestOptions: options, statusCode: status),
    type: DioExceptionType.badResponse,
  );
}
