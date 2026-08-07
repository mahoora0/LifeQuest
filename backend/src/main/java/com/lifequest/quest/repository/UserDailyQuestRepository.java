package com.lifequest.quest.repository;

import com.lifequest.quest.domain.QuestCadence;
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

    /**
     * 한 주기의 특정 트랙 배정 수.
     *
     * <p><b>퀘스트 원본의 cadence까지 봐야 한다.</b> {@code assignedDate}만으로 세면 월요일에
     * 틀린다 — 그날은 일간의 논리적 일자와 주간의 주기 시작일이 같은 날짜라 두 트랙이 한꺼번에
     * 잡힌다. {@code UserDailyQuest}에 트랙 컬럼이 없어 조인이 필요하다.
     */
    @Query("""
        select count(udq) from UserDailyQuest udq, Quest q
        where udq.questId = q.id
          and udq.userId = :userId
          and udq.assignedDate = :periodStart
          and q.cadence = :cadence
        """)
    long countByCadence(@Param("userId") Long userId,
                        @Param("periodStart") LocalDate periodStart,
                        @Param("cadence") QuestCadence cadence);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT udq FROM UserDailyQuest udq WHERE udq.id = :id")
    Optional<UserDailyQuest> findByIdForUpdate(@Param("id") Long id);

    long countByUserId(Long userId);

    long countByUserIdAndStatus(Long userId, com.lifequest.quest.domain.DailyQuestStatus status);

    List<UserDailyQuest> findTop10ByUserIdOrderByAssignedDateDescIdDesc(Long userId);
}
