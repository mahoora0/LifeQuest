package com.lifequest.group.dto;
import com.lifequest.group.*;
import java.time.LocalDateTime;
import java.util.List;
public record GroupQuestResponse(Long id,Long groupId,String groupName,Long createdByUserId,String creatorNickname,String title,String description,String placeName,LocalDateTime scheduledAt,GroupQuestStatus status,int expReward,long participantCount,GroupQuestParticipationStatus myParticipationStatus,List<GroupQuestParticipantResponse> participants,LocalDateTime completedAt,LocalDateTime createdAt,LocalDateTime updatedAt) {
    public static GroupQuestResponse from(GroupQuest q){return new GroupQuestResponse(q.getId(),q.getGroup().getId(),q.getGroup().getName(),q.getCreatedBy().getId(),q.getCreatedBy().getNickname(),q.getTitle(),q.getDescription(),q.getPlaceName(),q.getScheduledAt(),q.getStatus(),q.getExpReward(),0,null,null,q.getCompletedAt(),q.getCreatedAt(),q.getUpdatedAt());}
}
