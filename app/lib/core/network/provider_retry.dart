import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final status = ApiException.from(error).statusCode;
  if (status != null && status >= 400 && status < 500) return null;

  return ProviderContainer.defaultRetry(retryCount, error);
}
