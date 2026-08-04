package com.lifequest.group;

import jakarta.persistence.LockModeType;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface GroupMemberRepository extends JpaRepository<GroupMember, Long> {
    @EntityGraph(attributePaths = {"group", "group.owner", "user"})
    Optional<GroupMember> findByGroupIdAndUserId(Long groupId, Long userId);
    long countByGroupIdAndStatus(Long groupId, GroupMemberStatus status);
    Page<GroupMember> findByUserIdAndStatusOrderByIdDesc(Long userId, GroupMemberStatus status, Pageable pageable);
    @EntityGraph(attributePaths = "user")
    Page<GroupMember> findByGroupIdAndStatusOrderByIdAsc(Long groupId, GroupMemberStatus status, Pageable pageable);
    @EntityGraph(attributePaths = {"group", "group.owner", "user", "invitedBy"})
    Page<GroupMember> findByUserIdAndStatusAndExpiresAtAfterOrderByIdDesc(Long userId, GroupMemberStatus status, LocalDateTime now, Pageable pageable);
    @Query("select m from GroupMember m where m.user.id=:userId and m.status='INVITED' and m.expiresAt<=:now")
    List<GroupMember> findExpiredInvitationsForUser(@Param("userId") Long userId, @Param("now") LocalDateTime now);
    @EntityGraph(attributePaths = "user")
    Page<GroupMember> findByGroupIdAndStatusOrderByIdDesc(Long groupId, GroupMemberStatus status, Pageable pageable);

    @Query("select count(m) from GroupMember m where m.group.id=:groupId and m.status='INVITED' and m.expiresAt>:now")
    long countValidInvitations(@Param("groupId") Long groupId, @Param("now") LocalDateTime now);

    @Query("select m from GroupMember m where m.group.id=:groupId and m.status='INVITED' and m.expiresAt<=:now")
    List<GroupMember> findExpiredInvitations(@Param("groupId") Long groupId, @Param("now") LocalDateTime now);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select m from GroupMember m join fetch m.group join fetch m.user where m.id=:id")
    Optional<GroupMember> findByIdForUpdate(@Param("id") Long id);

    @EntityGraph(attributePaths = {"group", "group.owner"})
    @Query("select m from GroupMember m where m.user.id=:userId and m.status='ACTIVE' order by m.id desc")
    List<GroupMember> findActiveGroups(@Param("userId") Long userId);
}
