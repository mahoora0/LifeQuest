package com.lifequest.quest.repository;

import com.lifequest.quest.domain.WeeklyAiQuestClaim;
import java.time.LocalDate;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 주간 AI 슬롯 사용 기록 저장소.
 *
 * <p>{@code exists} 조회를 두지 않는다 — {@link QuestAssignmentMarkerRepository}와 같은 이유다.
 * "이미 받았는가"를 조회로 판정하면 두 요청이 모두 "없음"을 보는 창이 남는다. 판정은
 * {@code saveAndFlush} 시점의 유니크 제약 위반으로만 하며, 호출부는 제약 <b>이름</b>으로
 * 원인을 갈라야 한다(주당 1회인지, 후보 중복 소비인지).
 */
public interface WeeklyAiQuestClaimRepository extends JpaRepository<WeeklyAiQuestClaim, Long> {

    /** 화면 표시용 — 이번 주에 이미 받았는지 앱에 알려줄 때만 쓴다. 판정 근거로 쓰지 않는다. */
    boolean existsByUserIdAndPeriodStart(Long userId, LocalDate periodStart);
}
