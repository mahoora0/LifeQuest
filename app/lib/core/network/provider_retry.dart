import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/core/location/location_service.dart';
import 'package:life_quest/core/network/api_exception.dart';

/// 조회 실패 시 provider를 다시 부를지 정하는 정책.
///
/// Riverpod 3은 기본으로 200ms부터 6.4초까지 늘려 가며 최대 10번 재시도한다.
/// 재시도가 도는 동안 상태는 계속 `AsyncLoading`이라, 화면은 오류도 안내도 띄우지
/// 못하고 40초 가까이 로딩만 보여준다.
///
/// 4xx는 같은 요청을 다시 보내도 결과가 달라지지 않는다 — 서버에 없는 엔드포인트,
/// 없는 리소스, 만료된 토큰 모두 재시도가 의미 없다. 그래서 즉시 실패로 확정해
/// 화면이 제 상태를 그릴 수 있게 한다.
///
/// 5xx와 연결 실패(상태 코드 없음)만 기본 정책에 맡긴다. 그쪽은 잠시 뒤 성공할 수 있다.
Duration? lqProviderRetry(int retryCount, Object error) {
  // 위치 실패도 즉시 확정한다. 권한 거부·GPS 꺼짐·fix 실패는 몇 초 뒤 다시 물어도
  // 같은 답이 오고, 사용자가 설정을 바꿔야 풀리는 종류다. 상태 코드가 없어서
  // 아래 4xx 규칙에 걸리지 않으므로 여기서 따로 가른다 — 걸러 내지 않으면 지도가
  // 오류 안내 대신 40초 가까이 로딩만 돈다.
  if (error is LocationServiceException) return null;

  final status = ApiException.from(error).statusCode;
  if (status != null && status >= 400 && status < 500) return null;

  return ProviderContainer.defaultRetry(retryCount, error);
}
