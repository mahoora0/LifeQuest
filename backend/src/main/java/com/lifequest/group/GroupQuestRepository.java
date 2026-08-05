package com.lifequest.group;

import java.time.LocalDateTime;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface GroupQuestRepository extends JpaRepository<GroupQuest, Long> {
    @EntityGraph(attributePaths = "createdBy")
    Optional<GroupQuest> findByIdAndGroupId(Long id, Long groupId);
    @EntityGraph(attributePaths = "createdBy")
    @Query("select q from GroupQuest q where q.group.id=:groupId and q.status='PUBLISHED' and q.scheduledAt>:now order by q.scheduledAt asc, q.id asc")
    Page<GroupQuest> findUpcoming(@Param("groupId") Long groupId, @Param("now") LocalDateTime now, Pageable pageable);
    @EntityGraph(attributePaths = "createdBy")
    @Query("select q from GroupQuest q where q.group.id=:groupId and (q.status='CANCELLED' or q.scheduledAt<=:now) order by q.scheduledAt desc, q.id desc")
    Page<GroupQuest> findPast(@Param("groupId") Long groupId, @Param("now") LocalDateTime now, Pageable pageable);
    @EntityGraph(attributePaths = "createdBy")
    @Query("select q from GroupQuest q where q.group.id=:groupId order by q.scheduledAt desc, q.id desc")
    java.util.List<GroupQuest> findRecent(@Param("groupId") Long groupId, Pageable pageable);
}
