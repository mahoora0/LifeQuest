package com.lifequest.admin.dto;

import com.lifequest.quest.domain.CompletionType;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.domain.QuestCategory;
import com.lifequest.quest.domain.QuestCreator;
import com.lifequest.quest.domain.QuestGrade;
import java.math.BigDecimal;
import java.time.LocalDateTime;

public record AdminQuestResponse(
        Long id,
        String title,
        String description,
        QuestCategory category,
        QuestGrade grade,
        QuestCadence cadence,
        CompletionType completionType,
        int expReward,
        String placeName,
        BigDecimal latitude,
        BigDecimal longitude,
        Integer radiusM,
        Long lifedexItemId,
        QuestCreator createdBy,
        boolean active,
        LocalDateTime createdAt) {
    public static AdminQuestResponse from(Quest quest) {
        return new AdminQuestResponse(
                quest.getId(), quest.getTitle(), quest.getDescription(), quest.getCategory(), quest.getGrade(),
                quest.getCadence(), quest.getCompletionType(), quest.getExpReward(),
                quest.getPlaceName(), quest.getLatitude(), quest.getLongitude(), quest.getRadiusM(),
                quest.getLifedexItemId(), quest.getCreatedBy(), quest.isActive(), quest.getCreatedAt());
    }
}
