package com.lifequest.recommendation;

import jakarta.persistence.LockModeType;
import java.time.LocalDate;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface WeeklyRecommendationCandidateRepository
        extends JpaRepository<WeeklyRecommendationCandidate, Long> {

    /**
     * 선택 대상 후보를 잠그고 읽는다. {@code claimed_at}을 읽고 쓰는 사이에 다른 요청이 같은 행을
     * 가져가지 못하게 한다 — 최종 방어는 {@code uk_weekly_ai_claim_candidate}지만, 락이 있으면
     * 경합이 제약 위반이 아니라 순서로 정리돼 응답이 더 정확해진다.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select c from WeeklyRecommendationCandidate c where c.id = :id")
    Optional<WeeklyRecommendationCandidate> findByIdForUpdate(@Param("id") Long id);

    /**
     * 보관 기간이 지난 <b>미선택</b> 후보를 지운다({@link WeeklyRecommendationCandidateStore}).
     *
     * <p>{@code claimedAt IS NULL}이 빠지면 {@code weekly_ai_quest_claims.candidate_id} FK가
     * 걸려 삭제가 실패한다. 선택된 후보는 claim의 근거라 지워서도 안 된다.
     *
     * <p>사용자 단위로만 지운다 — 전체를 훑으면 요청 하나가 테이블 전체를 잠글 수 있다.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
        delete from WeeklyRecommendationCandidate c
        where c.userId = :userId
          and c.claimedAt is null
          and c.periodStart < :oldestKeptPeriod
        """)
    int deleteStaleUnclaimed(@Param("userId") Long userId,
                             @Param("oldestKeptPeriod") LocalDate oldestKeptPeriod);

    long countByUserIdAndPeriodStart(Long userId, LocalDate periodStart);
}
