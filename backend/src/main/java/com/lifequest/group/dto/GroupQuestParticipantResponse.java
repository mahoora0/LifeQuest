package com.lifequest.group.dto;

import com.lifequest.group.GroupQuestParticipant;
import com.lifequest.group.GroupQuestParticipationStatus;
import java.time.LocalDateTime;

public record GroupQuestParticipantResponse(
    Long userId,
    String nickname,
    GroupQuestParticipationStatus status,
    LocalDateTime appliedAt,
    LocalDateTime rewardedAt
) {
    public static GroupQuestParticipantResponse from(GroupQuestParticipant participant) {
        return new GroupQuestParticipantResponse(
            participant.getUser().getId(),
            participant.getUser().getNickname(),
            participant.getStatus(),
            participant.getAppliedAt(),
            participant.getRewardedAt());
    }
}
