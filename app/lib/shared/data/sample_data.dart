import 'package:flutter/foundation.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/shared/error/lq_error_messages.dart';

/// 서버가 아직 열리지 않은 구간에서 화면 검토용 표본을 내주는 관문.
///
/// 표본 없이 없는 엔드포인트를 호출하면 화면이 늘 오류 상태로만 보여 레이아웃과
/// 상호작용을 전혀 검토할 수 없다. 그렇다고 표본을 그대로 두면 회수를 잊었을 때
/// 사용자에게 거짓 데이터가 나간다.
///
/// 그래서 표본은 **디버그 빌드에서만** 나온다. 릴리스 빌드에서는 [guard]가
/// 404로 떨어져 화면이 "준비 중" 안내로 바뀌므로, 회수를 잊어도 가짜 수치가
/// 배포되지 않는다. 표본을 쓰는 저장소는 예외 없이 [guard]를 먼저 통과시킨다.
///
/// 회수 방법 — 저장소 메서드 본문을 Dio 호출로 바꾸고 [guard] 호출을 지운다.
/// 남은 호출부는 `rg 'LqSampleData'` 로 한 번에 찾을 수 있다.
abstract final class LqSampleData {
  /// 표본을 내줄지. 테스트는 디버그로 돌아가므로 표본을 그대로 검증할 수 있다.
  static const enabled = kDebugMode;

  /// 표본을 내주기 전에 부른다. 릴리스 빌드에서는 준비 중으로 떨어진다.
  ///
  /// 부를 엔드포인트 자체가 없는 구간(친구·알림)에 쓴다. 호출할 경로가 있으면
  /// [orSample]을 쓰는 쪽이 낫다 — 그쪽은 서버가 생기면 저절로 물러난다.
  ///
  /// 404 + `RESOURCE_NOT_FOUND`가 아닌 코드라야 `isFeatureNotReady`가 참이 되어
  /// 오류 화면이 아닌 준비 중 안내로 간다.
  static void guard(String feature) {
    if (enabled) return;
    throw ApiException(
      code: 'FEATURE_NOT_READY',
      message: '$feature은(는) 아직 준비 중이에요',
      statusCode: 404,
    );
  }

  /// 실제 호출을 먼저 시도하고, **엔드포인트가 아직 없을 때만** 표본으로 떨어진다.
  ///
  /// [guard]와 달리 회수가 자동이다 — 서버가 그 경로를 열면 [call]이 성공하므로
  /// 표본은 두 번 다시 쓰이지 않는다. 지우는 것을 잊어도 가짜가 실데이터를 덮지 않는다.
  ///
  /// 떨어지는 조건을 404로 좁힌 이유는, 네트워크 단절이나 500까지 표본으로 가리면
  /// 서버가 죽은 것을 개발 중에 알아채지 못하기 때문이다. 릴리스 빌드에서는
  /// [enabled]가 거짓이라 404가 그대로 올라가 준비 중 안내로 간다.
  static Future<T> orSample<T>(
    Future<T> Function() call,
    T Function() sample,
  ) async {
    try {
      return await call();
    } on Object catch (error) {
      if (enabled && isFeatureNotReady(error)) return sample();
      rethrow;
    }
  }
}
