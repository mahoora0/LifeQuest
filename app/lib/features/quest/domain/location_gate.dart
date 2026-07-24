import 'package:life_quest/core/location/geo_math.dart';

/// 클라이언트 위치 게이트 판정 결과.
enum LocationGate {
  /// accuracy를 신뢰할 수 없음(0 이하). 에뮬레이터·모의 위치가 이 값을 준다.
  accuracyUnknown,

  /// accuracy가 허용 상한 `min(radius_m, 100)`을 넘음.
  accuracyTooLow,

  /// 목표까지 거리가 인증 반경을 넘음.
  outOfRadius,

  /// 인증 요청을 보낼 수 있는 상태.
  withinRadius,
}

/// 인증 버튼을 열어도 되는지 판정한다.
///
/// **UI 안내 전용이며 최종 판정은 서버가 한다**(`05-business-rules.md` §3-2).
/// 여기서 하는 일은 "서버가 확실히 거절할 요청"을 미리 막는 것뿐이다.
///
/// - `accuracy <= 0`은 통과시키지 않는다. 서버는 `accuracy > 0`을 요구하므로
///   통과시키면 반드시 거절당할 요청을 사용자에게 권하는 꼴이 된다.
/// - [radiusM]이 null이면 **반경 판정을 하지 않는다**. 기본값을 추측해 막으면
///   실제로는 인증 가능한 퀘스트를 앱이 영구히 차단할 수 있다.
LocationGate evaluateLocationGate({
  required double accuracy,
  required double? distanceM,
  required int? radiusM,
}) {
  if (accuracy <= 0) return LocationGate.accuracyUnknown;
  if (accuracy > accuracyLimitM(radiusM ?? 100)) {
    return LocationGate.accuracyTooLow;
  }
  if (radiusM != null && distanceM != null && distanceM > radiusM) {
    return LocationGate.outOfRadius;
  }
  return LocationGate.withinRadius;
}
