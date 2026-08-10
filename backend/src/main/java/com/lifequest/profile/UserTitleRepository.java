package com.lifequest.profile;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserTitleRepository extends JpaRepository<UserTitle, Long> {
    boolean existsByUserIdAndTitleId(Long userId, Long titleId);

    @EntityGraph(attributePaths = "title")
    List<UserTitle> findAllByUserIdOrderByAcquiredAtDesc(Long userId);

    @EntityGraph(attributePaths = "title")
    Optional<UserTitle> findByUserIdAndTitleId(Long userId, Long titleId);

    /** 동시에 여러 퀘스트가 완료되어도 사용자별 칭호는 한 번만 지급한다. */
    @Modifying
    @Query(value = """
            INSERT IGNORE INTO user_titles
                (user_id, title_id, source_type, source_id, acquired_at)
            SELECT :userId, t.id, :sourceType, :sourceId, CURRENT_TIMESTAMP(6)
            FROM titles t
            WHERE t.code = :titleCode
            """, nativeQuery = true)
    int insertIfAbsent(
            @Param("userId") Long userId,
            @Param("titleCode") String titleCode,
            @Param("sourceType") String sourceType,
            @Param("sourceId") Long sourceId);

    @Modifying
    @Query(value = """
            INSERT IGNORE INTO user_titles
                (user_id, title_id, source_type, source_id, acquired_at)
            VALUES (:userId, :titleId, 'ACHIEVEMENT', :sourceId, CURRENT_TIMESTAMP(6))
            """, nativeQuery = true)
    int insertAchievementRewardIfAbsent(
            @Param("userId") Long userId,
            @Param("titleId") Long titleId,
            @Param("sourceId") Long sourceId);
}
