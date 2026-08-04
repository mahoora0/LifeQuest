package com.lifequest.social;

import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

// 친구 관계 엔티티에 대한
public interface FriendshipRepository extends JpaRepository<Friendship, Long> {

    boolean existsByUserIdAndFriendId(Long userId, Long friendId);

    @EntityGraph(attributePaths = "friend")
    Page<Friendship> findAllByUserIdOrderByCreatedAtDescIdDesc(
            Long userId,
            Pageable pageable);

    List<Friendship> findAllByUserId(Long userId);

    long deleteByUserIdAndFriendId(Long userId, Long friendId);
}
