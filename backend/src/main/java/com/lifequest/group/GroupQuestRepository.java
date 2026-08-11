package com.lifequest.group;

import java.time.LocalDateTime;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface GroupQuestRepository extends JpaRepository<GroupQuest, Long> {
    boolean existsByGroupIdAndStatus(Long groupId, GroupQuestStatus status);
    @EntityGraph(attributePaths = "createdBy")
    Optional<GroupQuest> findByIdAndGroupId(Long id, Long groupId);
    @Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @EntityGraph(attributePaths = {"createdBy", "group", "group.owner"})
    @Query("select q from GroupQuest q where q.id=:id and q.group.id=:groupId")
    Optional<GroupQuest> findByIdAndGroupIdForUpdate(
        @Param("id") Long id, @Param("groupId") Long groupId);
    @EntityGraph(attributePaths = "createdBy")
    @Query("select q from GroupQuest q where q.group.id=:groupId and q.status='PUBLISHED' and q.scheduledAt>:now order by q.scheduledAt asc, q.id asc")
    Page<GroupQuest> findUpcoming(@Param("groupId") Long groupId, @Param("now") LocalDateTime now, Pageable pageable);
    @EntityGraph(attributePaths = "createdBy")
    @Query("select q from GroupQuest q where q.group.id=:groupId and (q.status='CANCELLED' or q.scheduledAt<=:now) order by q.scheduledAt desc, q.id desc")
    Page<GroupQuest> findPast(@Param("groupId") Long groupId, @Param("now") LocalDateTime now, Pageable pageable);
    @EntityGraph(attributePaths = "createdBy")
    @Query("select q from GroupQuest q where q.group.id=:groupId order by q.scheduledAt desc, q.id desc")
    java.util.List<GroupQuest> findRecent(@Param("groupId") Long groupId, Pageable pageable);

    @EntityGraph(attributePaths = {"createdBy", "group"})
    @Query("""
        select q from GroupQuest q
        where q.status='PUBLISHED' and q.scheduledAt>:now
          and exists (select m.id from GroupMember m
                      where m.group=q.group and m.user.id=:userId and m.status='ACTIVE')
        order by q.scheduledAt asc, q.id asc
        """)
    Page<GroupQuest> findMineUpcoming(
        @Param("userId") Long userId, @Param("now") LocalDateTime now, Pageable pageable);

    @EntityGraph(attributePaths = {"createdBy", "group"})
    @Query("""
        select q from GroupQuest q
        where (q.status<>'PUBLISHED' or q.scheduledAt<=:now)
          and exists (select m.id from GroupMember m
                      where m.group=q.group and m.user.id=:userId and m.status='ACTIVE')
        order by q.scheduledAt desc, q.id desc
        """)
    Page<GroupQuest> findMinePast(
        @Param("userId") Long userId, @Param("now") LocalDateTime now, Pageable pageable);

    @Modifying
    @Query("delete from GroupQuest q where q.group.id=:groupId")
    int deleteAllByGroupId(@Param("groupId") Long groupId);
}
