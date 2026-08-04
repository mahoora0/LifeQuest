package com.lifequest.group.dto;
import com.lifequest.group.*;
import java.time.LocalDateTime;
public record GroupQuestResponse(Long id,Long groupId,Long createdByUserId,String creatorNickname,String title,String description,String placeName,LocalDateTime scheduledAt,GroupQuestStatus status,LocalDateTime createdAt,LocalDateTime updatedAt) {
    public static GroupQuestResponse from(GroupQuest q){return new GroupQuestResponse(q.getId(),q.getGroup().getId(),q.getCreatedBy().getId(),q.getCreatedBy().getNickname(),q.getTitle(),q.getDescription(),q.getPlaceName(),q.getScheduledAt(),q.getStatus(),q.getCreatedAt(),q.getUpdatedAt());}
}
