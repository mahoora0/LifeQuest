package com.lifequest.recommendation;

import jakarta.persistence.LockModeType;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
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
}
