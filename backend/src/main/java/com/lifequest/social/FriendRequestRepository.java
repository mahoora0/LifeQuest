package com.lifequest.social;

import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;

// 친구 요청 엔티티에 대한
public interface FriendRequestRepository extends JpaRepository<FriendRequest, Long> {

        boolean existsBySenderIdAndReceiverIdAndStatus(
                        Long senderId,
                        Long receiverId,
                        FriendRequestStatus status);

        @EntityGraph(attributePaths = "sender")
        Page<FriendRequest> findAllByReceiverIdAndStatusOrderByCreatedAtDescIdDesc(
                        Long receiverId,
                        FriendRequestStatus status,
                        Pageable pageable);

        Optional<FriendRequest> findByIdAndReceiverId(Long requestId, Long receiverId);

        // 같은 친구 요청을 두 요청이 동시에 처리하지 못하도록 잠금
        @Lock(LockModeType.PESSIMISTIC_WRITE)
        @Query("""
                        select request
                        from FriendRequest request
                        join fetch request.sender
                        join fetch request.receiver
                        where request.id = :requestId
                        """)
        Optional<FriendRequest> findByIdForUpdate(@Param("requestId") Long requestId);
}
