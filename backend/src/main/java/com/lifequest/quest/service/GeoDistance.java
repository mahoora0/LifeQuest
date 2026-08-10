package com.lifequest.quest.service;

/**
 * 두 좌표 사이의 지표면 거리(m). Haversine 공식을 쓴다.
 *
 * <p><b>완료 판정용이 아니다.</b> 반경 안팎을 가르는 계산은
 * {@link QuestCompletionServiceImpl}이 자기 안에서 수행하며, 그쪽은 경계값 테스트로 고정되어
 * 있다. 이 유틸은 {@code GET /quests/nearby}가 <b>표시용 거리</b>를 채우는 데 쓴다.
 *
 * <p>두 구현이 같은 공식을 쓰지만 한 곳으로 합치지 않았다 — 완료 경로의 거리 계산은 계약
 * 테스트가 걸려 있는 코드라 이번 변경의 범위 밖이다. 통합한다면 완료 쪽 테스트가 통과하는지를
 * 근거로 삼아 별도로 진행한다.
 *
 * <p>{@link #offset}은 배정이 쓴다. 거리를 재는 것이 아니라 만드는 쪽이지만 같은 구면 모델을
 * 공유하므로 여기 둔다 — 두 계산이 다른 지구 반지름을 쓰면 "반경의 60% 지점에 두었는데
 * 판정에서는 반경 밖"이 될 수 있다.
 */
final class GeoDistance {

    /** 지구 평균 반지름(m). 완료 경로와 같은 값을 쓴다. */
    private static final double EARTH_RADIUS_M = 6_371_000;

    private GeoDistance() {
    }

    /** 지표면의 한 지점. 좌표 두 개를 함께 돌려주기 위한 값이며 저장 단위가 아니다. */
    record Point(double latitude, double longitude) {
    }

    /**
     * 주어진 지점에서 방위각·거리만큼 떨어진 지점.
     *
     * <p>평면 근사(위도 1도 = 111km)를 쓰지 않는 이유는 경도 간격이 위도에 따라 좁아지기
     * 때문이다. 같은 경도 차이가 제주에서와 서울에서 다른 거리를 뜻하므로, 근사로 만든 지점은
     * 의도한 거리에서 어긋나고 그 어긋남은 위도가 높을수록 커진다. {@link #meters}가 구면으로
     * 재는 이상 만드는 쪽도 구면이어야 두 계산이 맞물린다.
     *
     * @param bearingDegrees 북쪽을 0도로 하는 시계 방향 방위각
     * @param distanceM      이동 거리(m)
     */
    static Point offset(double latitude, double longitude, double distanceM, double bearingDegrees) {
        double angular = distanceM / EARTH_RADIUS_M;
        double bearing = Math.toRadians(bearingDegrees);
        double latRad = Math.toRadians(latitude);
        double lonRad = Math.toRadians(longitude);

        double targetLat = Math.asin(
            Math.sin(latRad) * Math.cos(angular)
                + Math.cos(latRad) * Math.sin(angular) * Math.cos(bearing));

        double targetLon = lonRad + Math.atan2(
            Math.sin(bearing) * Math.sin(angular) * Math.cos(latRad),
            Math.cos(angular) - Math.sin(latRad) * Math.sin(targetLat));

        // 날짜변경선을 넘으면 경도가 ±180 밖으로 나간다. DECIMAL(10,7) 컬럼은 그 값도 받으므로
        // 저장은 되지만 지도가 엉뚱한 곳을 가리키고 거리 계산도 어긋난다. 한국에서는 닿지 않는
        // 경로지만 정규화 비용이 없어 여기서 처리한다
        double normalizedLon = (Math.toDegrees(targetLon) + 540) % 360 - 180;

        return new Point(Math.toDegrees(targetLat), normalizedLon);
    }

    static double meters(double lat1, double lon1, double lat2, double lon2) {
        double lat1Rad = Math.toRadians(lat1);
        double lat2Rad = Math.toRadians(lat2);
        double deltaLatRad = Math.toRadians(lat2 - lat1);
        double deltaLonRad = Math.toRadians(lon2 - lon1);

        double sinDeltaLatHalf = Math.sin(deltaLatRad / 2);
        double sinDeltaLonHalf = Math.sin(deltaLonRad / 2);

        double a = sinDeltaLatHalf * sinDeltaLatHalf
            + Math.cos(lat1Rad) * Math.cos(lat2Rad) * sinDeltaLonHalf * sinDeltaLonHalf;

        return EARTH_RADIUS_M * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }
}