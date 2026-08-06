package com.lifequest.quest;

import static org.assertj.core.api.Assertions.assertThat;

import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.service.QuestPeriod;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import org.junit.jupiter.api.Test;

/**
 * 주기 계산의 순수 계층 검증(docs/05-business-rules.md §1-1·§1-2).
 *
 * <p>논리적 일자는 <b>현재 시각 − 4시간</b>의 날짜다. 하루 경계를 자정이 아니라 04:00에 두는 이유는
 * 밤 활동이 자정에 잘리지 않게 하기 위함이며, 23:00과 다음날 01:00이 같은 논리적 일자가 된다.
 *
 * <p>주기 시작일은 트랙마다 다르다. 일간은 논리적 일자 당일, 주간은 <b>그 주 월요일</b>이다.
 * 주간을 월요일로 정규화하는 것은 표시상의 편의가 아니라 제약의 전제다 —
 * {@code uk_user_daily_quests(user_id, quest_id, assigned_date)}가 주기 단위 중복을 막으려면
 * 같은 주의 배정이 모두 같은 {@code assigned_date}를 가져야 한다. 요일 정렬이 없으면 사용자마다
 * 주가 다르게 시작해 DB 제약이 의도한 창을 막지 못한다.
 *
 * <p>만료는 <b>벽시계 04:00</b>이지 {@code 주기 시작 + 24시간}이 아니다. 20:00에 배정받아도 만료는
 * 다음 날 04:00이고, 02:00에 배정받으면 당일 04:00이라 수명이 2시간뿐이다.
 *
 * <p>두 규칙이 곱해지는 지점이 가장 틀리기 쉽다 — 일요일 23:00과 월요일 02:00은 논리적 일자가
 * 둘 다 일요일이므로 <b>같은 주</b>다. 04:00 경계와 요일 정렬 중 한쪽만 반영하면 여기서 갈린다.
 *
 * <p>이 계층이 틀려도 조용하다. 예외도 로그도 없이 날짜가 하루 밀리거나 주가 어긋날 뿐이므로
 * 고정 시각을 주입해 값으로 대조하는 방법 말고는 드러나지 않는다.
 */
class QuestPeriodTests {

    private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");

    /** 2026-08-06은 목요일. 그 주 월요일은 08-03, 일요일은 08-09, 다음 월요일은 08-10이다. */
    private static final LocalDate 이번주_월요일 = LocalDate.of(2026, 8, 3);
    private static final LocalDate 다음주_월요일 = LocalDate.of(2026, 8, 10);

    // ------------------------------------------------------------------
    // #7 04:00 경계 — 논리적 일자
    // ------------------------------------------------------------------

    @Test
    void 새벽_03시_59분의_논리적_일자는_전날이다() {
        assertThat(at("2026-08-06T03:59").logicalDate()).isEqualTo(LocalDate.of(2026, 8, 5));
    }

    @Test
    void 새벽_04시_01분의_논리적_일자는_당일이다() {
        assertThat(at("2026-08-06T04:01").logicalDate()).isEqualTo(LocalDate.of(2026, 8, 6));
    }

    @Test
    void 정각_04시부터_새_논리적_일자다() {
        assertThat(at("2026-08-06T04:00").logicalDate()).isEqualTo(LocalDate.of(2026, 8, 6));
    }

    @Test
    void 자정_직전은_아직_당일이다() {
        assertThat(at("2026-08-06T23:59").logicalDate()).isEqualTo(LocalDate.of(2026, 8, 6));
    }

    @Test
    void 자정을_넘겨도_04시_전이면_같은_논리적_일자다() {
        assertThat(at("2026-08-06T23:00").logicalDate())
            .isEqualTo(at("2026-08-07T01:00").logicalDate());
    }

    @Test
    void 시간대는_시스템_기본값이_아니라_주입된_Clock을_따른다() {
        // UTC 2026-08-05T18:30 = KST 2026-08-06T03:30 → 논리적 일자는 KST 기준 08-05.
        // 시스템 기본 시간대를 따랐다면 UTC 날짜인 08-05가 우연히 같게 나올 수 있으므로,
        // KST로는 이미 06일인데 논리적 일자가 05일이라는 점이 판별력을 만든다.
        QuestPeriod period = new QuestPeriod(
            Clock.fixed(LocalDateTime.parse("2026-08-05T18:30").atZone(ZoneId.of("UTC")).toInstant(),
                SEOUL));

        assertThat(period.logicalDate()).isEqualTo(LocalDate.of(2026, 8, 5));
    }

    // ------------------------------------------------------------------
    // 일간 주기 — 논리적 일자 당일 시작, 다음 날 04:00 만료
    // ------------------------------------------------------------------

    @Test
    void 일간_주기는_논리적_일자에서_시작한다() {
        assertThat(at("2026-08-06T10:00").create(QuestCadence.DAILY).getStartAt())
            .isEqualTo(LocalDate.of(2026, 8, 6));
    }

    @Test
    void 일간_만료는_다음_날_04시다() {
        assertThat(at("2026-08-06T10:00").create(QuestCadence.DAILY).getExpiresAt())
            .isEqualTo(LocalDateTime.of(2026, 8, 7, 4, 0));
    }

    @Test
    void 일간_만료는_배정_시각에_24시간을_더한_것이_아니다() {
        // 20:00 배정의 만료는 다음 날 04:00(8시간 뒤)이지 다음 날 20:00이 아니다.
        assertThat(at("2026-08-06T20:00").create(QuestCadence.DAILY).getExpiresAt())
            .isEqualTo(LocalDateTime.of(2026, 8, 7, 4, 0));
    }

    @Test
    void 새벽_배정은_당일_04시에_만료된다() {
        // 02:00의 논리적 일자는 전날(08-05)이므로 만료는 당일 04:00 — 수명이 2시간뿐이다.
        QuestPeriod.QuestLifePeriod period = at("2026-08-06T02:00").create(QuestCadence.DAILY);

        assertThat(period.getStartAt()).isEqualTo(LocalDate.of(2026, 8, 5));
        assertThat(period.getExpiresAt()).isEqualTo(LocalDateTime.of(2026, 8, 6, 4, 0));
    }

    // ------------------------------------------------------------------
    // #8 주간 정규화 — 그 주 월요일 시작, 다음 월요일 04:00 만료
    // ------------------------------------------------------------------

    @Test
    void 화요일_조회의_주기_시작일은_그_주_월요일이다() {
        assertThat(at("2026-08-04T10:00").create(QuestCadence.WEEKLY).getStartAt())
            .isEqualTo(이번주_월요일);
    }

    @Test
    void 일요일_조회의_주기_시작일도_같은_주_월요일이다() {
        assertThat(at("2026-08-09T10:00").create(QuestCadence.WEEKLY).getStartAt())
            .isEqualTo(이번주_월요일);
    }

    @Test
    void 화요일과_일요일의_주기_시작일이_같다() {
        assertThat(at("2026-08-04T10:00").create(QuestCadence.WEEKLY).getStartAt())
            .isEqualTo(at("2026-08-09T10:00").create(QuestCadence.WEEKLY).getStartAt());
    }

    @Test
    void 월요일_조회의_주기_시작일은_그날이다() {
        assertThat(at("2026-08-03T10:00").create(QuestCadence.WEEKLY).getStartAt())
            .isEqualTo(이번주_월요일);
    }

    @Test
    void 주간_만료는_다음_월요일_04시다() {
        assertThat(at("2026-08-04T10:00").create(QuestCadence.WEEKLY).getExpiresAt())
            .isEqualTo(LocalDateTime.of(2026, 8, 10, 4, 0));
    }

    // ------------------------------------------------------------------
    // 두 규칙이 곱해지는 지점 — 04:00 경계 × 요일 정렬
    // ------------------------------------------------------------------

    @Test
    void 일요일_23시와_월요일_02시는_같은_주다() {
        // 둘 다 논리적 일자가 일요일(08-09)이므로 주기 시작일은 08-03이어야 한다.
        // 04:00 경계를 빠뜨리면 월요일 02:00이 08-10으로 넘어가 새 주가 되어 버린다.
        assertThat(at("2026-08-09T23:00").create(QuestCadence.WEEKLY).getStartAt())
            .isEqualTo(at("2026-08-10T02:00").create(QuestCadence.WEEKLY).getStartAt())
            .isEqualTo(이번주_월요일);
    }

    @Test
    void 월요일_04시_01분부터_새_주가_시작된다() {
        QuestPeriod.QuestLifePeriod period = at("2026-08-10T04:01").create(QuestCadence.WEEKLY);

        assertThat(period.getStartAt()).isEqualTo(다음주_월요일);
        assertThat(period.getExpiresAt()).isEqualTo(LocalDateTime.of(2026, 8, 17, 4, 0));
    }

    // ------------------------------------------------------------------

    /** KST 벽시계 시각에 고정된 {@code QuestPeriod}. 운영과 같은 {@code Asia/Seoul}을 쓴다. */
    private static QuestPeriod at(String kstDateTime) {
        return new QuestPeriod(
            Clock.fixed(LocalDateTime.parse(kstDateTime).atZone(SEOUL).toInstant(), SEOUL));
    }
}
