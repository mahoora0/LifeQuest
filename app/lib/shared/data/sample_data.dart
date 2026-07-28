import 'package:flutter/foundation.dart';
import 'package:life_quest/core/network/api_exception.dart';

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
}
