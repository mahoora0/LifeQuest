package com.lifequest.growth;

import org.springframework.data.jpa.repository.JpaRepository;

public interface ExpLogRepository extends JpaRepository<ExpLog, Long> {
    boolean existsByUserIdAndSourceTypeAndSourceId(Long userId, String sourceType, Long sourceId);
}
