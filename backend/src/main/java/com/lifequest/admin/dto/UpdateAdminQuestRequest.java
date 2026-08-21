package com.lifequest.admin.dto;

import com.lifequest.quest.domain.CompletionType;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.domain.QuestCategory;
import com.lifequest.quest.domain.QuestGrade;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record UpdateAdminQuestRequest(
        @Size(min = 1, max = 100) String title,
        @Size(max = 500) String description,
        QuestCategory category,
        QuestGrade grade,
        QuestCadence cadence,
        CompletionType completionType,
        @Positive Integer expReward,
        @Size(max = 100) String placeName,
        BigDecimal latitude,
        BigDecimal longitude,
        Integer radiusM,
        Long lifedexItemId,
        Boolean active) {
}
