package com.lifequest.quest.repository;

import com.lifequest.quest.domain.UserDailyQuest;
import java.time.LocalDate;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserDailyQuestRepository extends JpaRepository<UserDailyQuest, Long> {

    /** 오늘의 퀘스트 조회. */
    List<UserDailyQuest> findByUserIdAndAssignedDate(Long userId, LocalDate assignedDate);

    /** 동일 퀘스트의 하루 중복 배정 방지 사전 확인(최종 방어는 UNIQUE 제약). */
    boolean existsByUserIdAndQuestIdAndAssignedDate(Long userId, Long questId, LocalDate assignedDate);
}
