package com.lifequest.quest.repository;

import com.lifequest.quest.domain.QuestCompletion;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface QuestCompletionRepository extends JpaRepository<QuestCompletion, Long> {

    /** 완료 멱등성 판정용 기존 완료 기록 조회(배정 ID 단위). */
    Optional<QuestCompletion> findByUserDailyQuestId(Long userDailyQuestId);

    /**
     * 완료·인증 기록 이력 조회(최신순). id를 보조 정렬키로 둔다 — completed_at은 유일하지 않으므로,
     * 같은 시각 완료건이 있으면 페이지마다 별개로 실행되는 LIMIT/OFFSET 질의의 동순위 순서가
     * 보장되지 않아 한 건이 두 페이지에 중복되고 다른 건이 누락된다.
     */
    Page<QuestCompletion> findByUserIdOrderByCompletedAtDescIdDesc(Long userId, Pageable pageable);
}
