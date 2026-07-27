package com.lifequest.profile;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserProfileItemRepository extends JpaRepository<UserProfileItem, Long> {
    boolean existsByUserIdAndProfileItemId(Long userId, Long profileItemId);

    @EntityGraph(attributePaths = "profileItem")
    List<UserProfileItem> findAllByUserIdOrderByAcquiredAtDesc(Long userId);

    @EntityGraph(attributePaths = "profileItem")
    Optional<UserProfileItem> findByUserIdAndProfileItemId(Long userId, Long profileItemId);
}
