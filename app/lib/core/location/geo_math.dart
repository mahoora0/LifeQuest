import 'dart:math' as math;

/// 지구 평균 반지름(m).
const _earthRadiusM = 6371000.0;

/// 두 좌표 사이의 거리(m) — Haversine 공식.
///
/// 클라이언트 계산은 **UI 안내 전용**이다(반경 안/밖 배너, 남은 거리 표기).
/// 완료 처리의 최종 판정은 항상 서버가 수행한다
/// (`05-business-rules.md` §3-2 · `04-api-spec.md` §4).
double haversineDistanceM({
  required double lat1,
  required double lng1,
  required double lat2,
  required double lng2,
}) {
  final dLat = _toRadians(lat2 - lat1);
  final dLng = _toRadians(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * _earthRadiusM * math.asin(math.min(1, math.sqrt(a)));
}

/// 위치 정확도 허용 상한 — `min(radius_m, 100)` (`05-business-rules.md` §3-2).
double accuracyLimitM(int radiusM) => math.min(radiusM.toDouble(), 100);

double _toRadians(double degrees) => degrees * math.pi / 180;
