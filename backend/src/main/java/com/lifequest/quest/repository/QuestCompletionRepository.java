package com.lifequest.quest.repository;

import com.lifequest.quest.domain.QuestCompletion;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface QuestCompletionRepository extends JpaRepository<QuestCompletion, Long> {

    /** 완료 멱등성 판정용 기존 완료 기록 조회(배정 ID 단위). */
    Optional<QuestCompletion> findByUserDailyQuestId(Long userDailyQuestId);

    /** 완료·인증 기록 이력 조회(최신순). */
    Page<QuestCompletion> findByUserIdOrderByCompletedAtDesc(Long userId, Pageable pageable);
}
