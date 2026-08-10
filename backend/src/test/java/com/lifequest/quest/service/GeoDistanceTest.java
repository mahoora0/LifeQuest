package com.lifequest.quest.service;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

/**
 * {@link GeoDistance}의 두 방향 — 재는 쪽과 만드는 쪽.
 *
 * <p><b>맞물림을 잰다.</b> {@code offset}으로 d미터 떨어뜨린 지점을 {@code meters}로 다시 재면
 * d가 나와야 한다. 둘이 다른 지구 모델을 쓰면 "반경의 60% 지점에 두었는데 판정에서는 반경 밖"이
 * 되는데, 각각을 따로 검증하면 그 어긋남이 드러나지 않는다 — 두 함수 모두 자기 안에서는 옳다.
 */
class GeoDistanceTest {

    private static final double SEOUL_LAT = 37.5665;
    private static final double SEOUL_LNG = 126.9780;

    @ParameterizedTest(name = "{0}도 방향")
    @ValueSource(doubles = {0, 45, 90, 135, 180, 225, 270, 315, 359.9})
    void 만든_지점을_다시_재면_의도한_거리가_나온다(double bearing) {
        double distanceM = 400;

        GeoDistance.Point point = GeoDistance.offset(SEOUL_LAT, SEOUL_LNG, distanceM, bearing);
        double measured = GeoDistance.meters(
            SEOUL_LAT, SEOUL_LNG, point.latitude(), point.longitude());

        assertThat(measured)
            .as("%.0f도 방향으로 %.0fm 떨어뜨렸는데 다시 재니 %.2fm다".formatted(bearing, distanceM, measured))
            .isCloseTo(distanceM, within(0.5));
    }

    /**
     * 방위각이 뜻대로 도는지. 북(0도)은 위도만, 동(90도)은 경도만 늘린다.
     *
     * <p>거리만 재면 부호가 뒤집혀도 통과한다 — 남쪽으로 400m 간 지점도 400m 떨어져 있다.
     */
    @Test
    void 방위각이_북쪽과_동쪽을_구분한다() {
        GeoDistance.Point north = GeoDistance.offset(SEOUL_LAT, SEOUL_LNG, 400, 0);
        GeoDistance.Point east = GeoDistance.offset(SEOUL_LAT, SEOUL_LNG, 400, 90);

        assertThat(north.latitude()).isGreaterThan(SEOUL_LAT);
        assertThat(north.longitude()).isCloseTo(SEOUL_LNG, within(1e-9));

        assertThat(east.longitude()).isGreaterThan(SEOUL_LNG);
        assertThat(east.latitude()).isCloseTo(SEOUL_LAT, within(1e-6));
    }

    /**
     * 위도가 다르면 같은 거리가 다른 경도 차이를 뜻한다. 평면 근사(위도 1도 = 111km)로 만들면
     * 이 차이가 사라져 고위도에서 의도한 거리를 벗어난다.
     */
    @Test
    void 경도_간격이_위도에_따라_좁아지는_것을_반영한다() {
        double distanceM = 1_000;

        double nearEquator = GeoDistance.offset(5.0, 100.0, distanceM, 90).longitude() - 100.0;
        double nearPole = GeoDistance.offset(65.0, 100.0, distanceM, 90).longitude() - 100.0;

        assertThat(nearPole)
            .as("고위도에서 같은 거리가 더 큰 경도 차이여야 한다 — 평면 근사면 둘이 같아진다")
            .isGreaterThan(nearEquator * 2);
    }

    /** 거리 0이면 제자리다. 템플릿 오프셋의 하한이 0으로 잘못 설정돼도 좌표가 깨지지는 않아야 한다. */
    @Test
    void 거리가_0이면_같은_지점이다() {
        GeoDistance.Point point = GeoDistance.offset(SEOUL_LAT, SEOUL_LNG, 0, 123);

        assertThat(point.latitude()).isCloseTo(SEOUL_LAT, within(1e-9));
        assertThat(point.longitude()).isCloseTo(SEOUL_LNG, within(1e-9));
    }

    /**
     * 날짜변경선을 넘어도 경도가 ±180 안에 남는다. 한국에서는 닿지 않는 경로지만, 정규화가
     * 빠지면 저장은 되고 지도만 엉뚱한 곳을 가리켜 조용하다.
     */
    @Test
    void 날짜변경선을_넘어도_경도가_정규화된다() {
        GeoDistance.Point point = GeoDistance.offset(0, 179.999, 1_000, 90);

        assertThat(point.longitude()).isBetween(-180.0, 180.0);
        assertThat(point.longitude())
            .as("동쪽으로 넘었으므로 -180 쪽에서 다시 나와야 한다")
            .isNegative();
    }
}
