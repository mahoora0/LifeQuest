package com.lifequest.quest.dto;

import com.lifequest.quest.domain.QuestGrade;
import java.time.LocalDateTime;

public record QuestHistoryItemResponse(
        Long completionId,
        Long questId,
        String title,
        QuestGrade grade,
        int expReward,
        LocalDateTime completedAt) {
}
