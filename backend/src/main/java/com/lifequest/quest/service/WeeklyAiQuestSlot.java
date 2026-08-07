package com.lifequest.quest.service;

import com.lifequest.common.exception.ErrorCode;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.repository.UserDailyQuestRepository;
import com.lifequest.quest.repository.WeeklyAiQuestClaimRepository;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

/**
 * 이번 주 AI 슬롯이 열려 있는가(docs/05-business-rules.md §1-D).
 *
 * <p>추천 생성과 선택이 <b>같은 판정</b>을 써야 한다. 추천 쪽에만 있으면 API를 직접 부르는
 * 경로가 남고, 선택 쪽에만 있으면 이미 받은 사용자가 LLM 비용을 계속 쓴다.
 *
 * <h2>이 조회는 동시성 판정이 아니다</h2>
 * 주당 1회의 최종 보장은 {@code uk_weekly_ai_claim_period}이고 그건 그대로 둔다. 여기서 하는
 * 것은 <b>헛돈과 헛일을 막는 사전 검사</b>다 — 두 요청이 동시에 "열림"을 봐도 제약이 하나만
 * 통과시킨다.
 */
@Component
public class WeeklyAiQuestSlot {

    /**
     * 주간 트랙의 총 슬롯 수. 자동이 2개(A·B)를 채우고 나머지 하나가 AI 자리다.
     *
     * <p>정상 상태에서는 자동이 2를 넘길 수 없어 이 상한에 걸리지 않는다. 걸리는 것은 슬롯
     * 규칙이 바뀌기 전에 만들어진 주기의 배정이 3개 남아 있는 동안뿐이며, 그때 AI까지 받으면
     * 주간이 4개가 된다. <b>이 불변식은 서버가 지켜야 한다</b> — 앱이 카드를 감추는 것만으로는
     * API를 직접 부르는 경로가 남는다.
     */
    public static final int WEEKLY_SLOTS = 3;

    private final WeeklyAiQuestClaimRepository claims;
    private final UserDailyQuestRepository assignments;
    private final QuestPeriod questPeriod;

    public WeeklyAiQuestSlot(WeeklyAiQuestClaimRepository claims,
                             UserDailyQuestRepository assignments,
                             QuestPeriod questPeriod) {
        this.claims = claims;
        this.assignments = assignments;
        this.questPeriod = questPeriod;
    }

    /**
     * 슬롯 상태. 닫혀 있으면 {@code reason}이 왜인지 말한다 — 사용자에게 할 말이 다르다
     * ("이미 받았다" vs "이번 주는 자리가 없다").
     */
    public record Availability(boolean open, ErrorCode reason) {
        static Availability available() {
            return new Availability(true, null);
        }

        static Availability blockedBy(ErrorCode reason) {
            return new Availability(false, reason);
        }
    }

    @Transactional(readOnly = true)
    public Availability availability(Long userId) {
        LocalDate periodStart = questPeriod.create(QuestCadence.WEEKLY).getStartAt();

        if (claims.existsByUserIdAndPeriodStart(userId, periodStart)) {
            return Availability.blockedBy(ErrorCode.WEEKLY_AI_QUEST_ALREADY_CLAIMED);
        }
        if (assignments.countByCadence(userId, periodStart, QuestCadence.WEEKLY) >= WEEKLY_SLOTS) {
            return Availability.blockedBy(ErrorCode.WEEKLY_AI_SLOT_UNAVAILABLE);
        }
        return Availability.available();
    }
}
