package com.lifequest.profile;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserTitleRepository extends JpaRepository<UserTitle, Long> {
    boolean existsByUserIdAndTitleId(Long userId, Long titleId);

    @EntityGraph(attributePaths = "title")
    List<UserTitle> findAllByUserIdOrderByAcquiredAtDesc(Long userId);

    @EntityGraph(attributePaths = "title")
    Optional<UserTitle> findByUserIdAndTitleId(Long userId, Long titleId);
}
