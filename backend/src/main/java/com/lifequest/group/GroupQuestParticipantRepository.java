package com.lifequest.group;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface GroupQuestParticipantRepository
    extends JpaRepository<GroupQuestParticipant, Long> {

    @EntityGraph(attributePaths = "user")
    Optional<GroupQuestParticipant> findByQuestIdAndUserId(Long questId, Long userId);

    @EntityGraph(attributePaths = "user")
    List<GroupQuestParticipant> findByQuestIdOrderByIdAsc(Long questId);

    @EntityGraph(attributePaths = "user")
    List<GroupQuestParticipant> findByQuestIdAndStatusOrderByIdAsc(
        Long questId, GroupQuestParticipationStatus status);

    long countByQuestIdAndStatusIn(
        Long questId, List<GroupQuestParticipationStatus> statuses);

    @Query("select p.status from GroupQuestParticipant p where p.quest.id=:questId and p.user.id=:userId")
    Optional<GroupQuestParticipationStatus> findStatus(
        @Param("questId") Long questId, @Param("userId") Long userId);

    @Modifying
    @Query("delete from GroupQuestParticipant p where p.quest.id=:questId")
    int deleteAllByQuestId(@Param("questId") Long questId);

    @Modifying
    @Query("delete from GroupQuestParticipant p where p.quest.group.id=:groupId")
    int deleteAllByGroupId(@Param("groupId") Long groupId);
}
