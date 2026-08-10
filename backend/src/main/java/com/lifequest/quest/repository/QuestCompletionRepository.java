package com.lifequest.quest.repository;

import com.lifequest.quest.domain.QuestCompletion;
import com.lifequest.quest.dto.QuestHistoryItemResponse;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface QuestCompletionRepository extends JpaRepository<QuestCompletion, Long> {

    /** 완료 멱등성 판정용 기존 완료 기록 조회(배정 ID 단위). */
    Optional<QuestCompletion> findByUserDailyQuestId(Long userDailyQuestId);

    /**
     * 완료·인증 기록 이력 조회(최신순). id를 보조 정렬키로 둔다 — completed_at은 유일하지 않으므로,
     * 같은 시각 완료 건이 있으면 페이지마다 별개로 실행되는 LIMIT/OFFSET 질의의 동순위 순서가
     * 보장되지 않아 한 건이 두 페이지에 중복되고 다른 건이 누락된다.
     */
    Page<QuestCompletion> findByUserIdOrderByCompletedAtDescIdDesc(Long userId, Pageable pageable);

    @Query(value = """
            SELECT new com.lifequest.quest.dto.QuestHistoryItemResponse(
                c.id, q.id, q.title, q.grade, q.expReward, c.completedAt)
            FROM QuestCompletion c
            JOIN Quest q ON q.id = c.questId
            WHERE c.userId = :userId
            ORDER BY c.completedAt DESC, c.id DESC
            """, countQuery = """
            SELECT COUNT(c.id)
            FROM QuestCompletion c
            WHERE c.userId = :userId
            """)
    Page<QuestHistoryItemResponse> findHistoryByUserId(
            @Param("userId") Long userId, Pageable pageable);

    long countByUserId(Long userId);

    long countByUserIdAndQuestId(Long userId, Long questId);

    @Query(value = """
            SELECT COUNT(*)
            FROM quest_completions qc
            JOIN quests q ON q.id = qc.quest_id
            WHERE qc.user_id = :userId
              AND q.completion_type = :completionType
            """, nativeQuery = true)
    long countByUserIdAndCompletionType(
            @Param("userId") Long userId,
            @Param("completionType") String completionType);

    @Query(value = """
            SELECT COUNT(*)
            FROM quest_completions qc
            JOIN quests q ON q.id = qc.quest_id
            WHERE qc.user_id = :userId
              AND q.cadence = :cadence
            """, nativeQuery = true)
    long countByUserIdAndCadence(
            @Param("userId") Long userId,
            @Param("cadence") String cadence);

    @Query(value = """
            SELECT COUNT(*)
            FROM quest_completions qc
            JOIN quests q ON q.id = qc.quest_id
            WHERE qc.user_id = :userId
              AND q.grade = :grade
            """, nativeQuery = true)
    long countByUserIdAndGrade(
            @Param("userId") Long userId,
            @Param("grade") String grade);

    /** 위치 좌표나 방문 시각은 노출하지 않고, 완료한 서로 다른 장소 수만 집계한다. */
    @Query(value = """
            SELECT COUNT(DISTINCT q.place_name)
            FROM quest_completions qc
            JOIN quests q ON q.id = qc.quest_id
            WHERE qc.user_id = :userId
              AND q.place_name IS NOT NULL
              AND TRIM(q.place_name) <> ''
            """, nativeQuery = true)
    long countDistinctVisitedPlacesByUserId(@Param("userId") Long userId);
}
