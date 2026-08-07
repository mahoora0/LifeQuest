package com.lifequest.recommendation;

import com.lifequest.quest.service.QuestPeriod;
import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 주간 퀘스트 추천의 기간 상한.
 *
 * <p>주간 만료는 "받은 날 + 7일"이 아니라 <b>그 주 월요일 04:00 + 7일 고정</b>이다. 토요일에 받은
 * 7일짜리 여행 퀘스트는 시작부터 이틀 뒤 만료라, 상한을 14일도 7일도 아닌 남은 일수로 둔다.
 *
 * <p><b>시각 차이로 세면 안 된다.</b> {@code ChronoUnit.DAYS.between(now, expiresAt)}은 실제 경과
 * 시간을 내림하므로 논리적 월요일 05:00에 이미 6을 준다 — 매일 하루씩 적게 나오고 04:00 경계에서
 * 또 어긋난다. 아래 표가 그 차이를 고정한다.
 */
class WeeklyRemainingDaysTests {

    /** 2026-08-03이 월요일이다. */
    private static final String MONDAY = "2026-08-03";

    @Test
    void 남은_일수는_논리적_요일을_따라_줄어든다() {
        assertThat(remainingDaysAt(MONDAY + "T05:00:00")).isEqualTo(7);
        assertThat(remainingDaysAt("2026-08-06T12:00:00")).isEqualTo(4);   // 목
        assertThat(remainingDaysAt("2026-08-08T12:00:00")).isEqualTo(2);   // 토
        assertThat(remainingDaysAt("2026-08-09T12:00:00")).isEqualTo(1);   // 일
    }

    /**
     * 04:00 경계. 월요일 03:00은 <b>논리적으로 아직 일요일</b>이라 지난 주기의 마지막 날이며,
     * 05:00이 되어야 새 주의 7일이 된다. 시각 기준으로 세면 이 자리가 뒤집힌다.
     */
    @Test
    void 주기_경계인_04시를_넘겨야_새_주의_칠일이_된다() {
        assertThat(remainingDaysAt(MONDAY + "T03:59:59"))
            .as("아직 지난 주의 마지막 날(일요일)이다")
            .isEqualTo(1);
        assertThat(remainingDaysAt(MONDAY + "T04:00:00")).isEqualTo(7);
    }

    /** 최소 1을 보장한다 — 0이나 음수가 나오면 상한이 무너져 검증이 모든 요청을 거부한다. */
    @Test
    void 남은_일수는_최소_하루다() {
        assertThat(remainingDaysAt("2026-08-09T23:59:59")).isGreaterThanOrEqualTo(1);
    }

    /**
     * remainingDays는 {@link QuestPeriod}만 쓰므로 나머지 협력자 없이 잴 수 있다.
     * LLM·저장소를 붙이지 않아야 이 계산이 그것들과 무관하게 고정된다.
     */
    private int remainingDaysAt(String localDateTime) {
        Clock clock = Clock.fixed(
            LocalDateTime.parse(localDateTime).toInstant(ZoneOffset.UTC),
            ZoneId.of("UTC"));
        return new WeeklyQuestRecommendationService(
            null, null, null, null, new QuestPeriod(clock), clock).remainingDays();
    }
}
