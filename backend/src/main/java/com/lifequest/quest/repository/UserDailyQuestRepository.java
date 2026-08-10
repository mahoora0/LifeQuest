package com.lifequest.quest.repository;

import com.lifequest.quest.domain.UserDailyQuest;
import jakarta.persistence.LockModeType;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserDailyQuestRepository extends JpaRepository<UserDailyQuest, Long> {

    /** 현재 유효한 배정 목록. 주기와 관계없이 만료 시각을 기준으로 조회한다. */
    List<UserDailyQuest> findByUserIdAndExpiresAtAfter(Long userId, LocalDateTime now);

    /** 특정 주기 시작일의 배정 목록. */
    List<UserDailyQuest> findByUserIdAndAssignedDate(Long userId, LocalDate assignedDate);

    /** 동일 퀘스트의 같은 주기 중복 배정을 사전에 확인한다. */
    boolean existsByUserIdAndQuestIdAndAssignedDate(Long userId, Long questId, LocalDate assignedDate);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT udq FROM UserDailyQuest udq WHERE udq.id = :id")
    Optional<UserDailyQuest> findByIdForUpdate(@Param("id") Long id);

    long countByUserId(Long userId);

    long countByUserIdAndStatus(Long userId, com.lifequest.quest.domain.DailyQuestStatus status);

    List<UserDailyQuest> findTop10ByUserIdOrderByAssignedDateDescIdDesc(Long userId);
}
