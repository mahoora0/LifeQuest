package com.lifequest.growth;

import java.time.Instant;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import org.springframework.data.jpa.repository.Query;

public interface ExpLogRepository extends JpaRepository<ExpLog, Long> {
    boolean existsByUserIdAndSourceTypeAndSourceId(Long userId, String sourceType, Long sourceId);

    /**
     * 특정 출처의 하루 지급 횟수. 인증 투표처럼 "하루 몇 번까지만 EXP"인 규칙이 별도 카운터
     * 테이블 없이 지급 이력만으로 판정되도록 한다 — 이력과 한도가 같은 사실을 두 곳에 적으면
     * 어긋날 수 있는데, 여기서는 어긋날 자리가 없다.
     */
    long countByUserIdAndSourceTypeAndCreatedAtGreaterThanEqual(
        Long userId, String sourceType, Instant from);

    List<ExpLog> findTop10ByOrderByCreatedAtDescIdDesc();

    List<ExpLog> findTop10ByUserIdOrderByCreatedAtDescIdDesc(Long userId);

    List<ExpLog> findAllByUserIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThanOrderByCreatedAtAsc(
        Long userId, Instant from, Instant to);

    @Query("select coalesce(sum(e.expAmount), 0) from ExpLog e")
    long sumExpAmount();
}
