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
 */
final class GeoDistance {

    /** 지구 평균 반지름(m). 완료 경로와 같은 값을 쓴다. */
    private static final double EARTH_RADIUS_M = 6_371_000;

    private GeoDistance() {
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