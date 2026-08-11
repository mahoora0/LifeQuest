package com.lifequest.group;

import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface GroupChatMessageRepository extends JpaRepository<GroupChatMessage, Long> {
    @EntityGraph(attributePaths = "sender")
    @Query("select m from GroupChatMessage m where m.group.id=:groupId order by m.id desc")
    List<GroupChatMessage> findLatest(@Param("groupId") Long groupId, Pageable pageable);
    @EntityGraph(attributePaths = "sender")
    @Query("select m from GroupChatMessage m where m.group.id=:groupId and m.id<:beforeId order by m.id desc")
    List<GroupChatMessage> findBefore(@Param("groupId") Long groupId, @Param("beforeId") Long beforeId, Pageable pageable);
    @EntityGraph(attributePaths = "sender")
    @Query("select m from GroupChatMessage m where m.group.id=:groupId and m.id>:afterId order by m.id asc")
    List<GroupChatMessage> findAfter(@Param("groupId") Long groupId, @Param("afterId") Long afterId, Pageable pageable);
    boolean existsByGroupIdAndIdLessThan(Long groupId, Long id);

    @Modifying
    @Query("delete from GroupChatMessage m where m.group.id=:groupId")
    int deleteAllByGroupId(@Param("groupId") Long groupId);
}
