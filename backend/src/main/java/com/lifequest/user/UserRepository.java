package com.lifequest.user;

import java.util.Optional;
import java.time.Instant;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

public interface UserRepository extends JpaRepository<User, Long> {

    @Query("""
            select u from User u
            where lower(u.nickname) like lower(concat('%', :query, '%'))
               or lower(u.email) like lower(concat('%', :query, '%'))
            """)
    Page<User> searchForAdmin(@Param("query") String query, Pageable pageable);

    long countByCreatedAtGreaterThanEqual(Instant from);

    Page<User> findAllByOrderByCreatedAtDesc(Pageable pageable);

    Optional<User> findByEmailIgnoreCase(String email);

    boolean existsByEmailIgnoreCase(String email);

    boolean existsByNickname(String nickname);

    boolean existsByNicknameAndIdNot(String nickname, Long id);

    Optional<User> findByFriendCodeIgnoreCaseAndIdNot(String friendCode, Long id);

    // 닉네임을 기준으로 사용자를 검색하는 데이터베이스 조회 기능 추가
    Page<User> findByNicknameContainingIgnoreCaseAndIdNot(
            String nickname,
            Long currentUserId,
            Pageable pageable);

    @Query("""
            select u from User u
            where u.id = :currentUserId
               or u.id in (
                   select f.friend.id from Friendship f
                   where f.user.id = :currentUserId
               )
            """)
    Page<User> findCurrentUserAndFriends(
            @Param("currentUserId") Long currentUserId,
            Pageable pageable);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select u from User u where u.id = :id")
    Optional<User> findByIdForUpdate(@Param("id") Long id);
}
