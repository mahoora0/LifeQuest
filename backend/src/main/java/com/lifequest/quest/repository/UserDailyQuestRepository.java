package com.lifequest.quest.repository;

import com.lifequest.quest.domain.UserDailyQuest;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface UserDailyQuestRepository extends JpaRepository<UserDailyQuest, Long> {

    /**
     * 유효한 배정 건 조회 — 목록 화면이 쓰는 기준이다(docs/05-business-rules.md §1-2).
     *
     * <p>{@code assignedDate}로 조회하지 않는 이유는 그 값이 트랙마다 다르기 때문이다. 화요일에
     * 조회하면 일간 배정의 {@code assignedDate}는 화요일이고 주간 배정은 그 주 월요일이라, 날짜
     * 하나로는 두 트랙을 함께 읽을 수 없다. 만료 시각을 기준으로 삼으면 트랙과 무관하게 "지금
     * 유효한 배정"이 한 번에 잡힌다.
     */
    List<UserDailyQuest> findByUserIdAndExpiresAtAfter(Long userId, LocalDateTime now);

    /** 특정 주기의 배정 조회. 트랙 구분이 없으므로 호출부가 주기 시작일로 범위를 좁힌다. */
    List<UserDailyQuest> findByUserIdAndAssignedDate(Long userId, LocalDate assignedDate);

    /** 동일 퀘스트의 하루 중복 배정 방지 사전 확인(최종 방어는 UNIQUE 제약). */
    boolean existsByUserIdAndQuestIdAndAssignedDate(Long userId, Long questId, LocalDate assignedDate);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT udq FROM UserDailyQuest udq WHERE udq.id = :id")
    Optional<UserDailyQuest> findByIdForUpdate(@Param("id") Long id);
}
