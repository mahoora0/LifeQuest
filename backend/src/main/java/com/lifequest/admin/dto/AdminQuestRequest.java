package com.lifequest.admin.dto;

import com.lifequest.quest.domain.CompletionType;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.domain.QuestGrade;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record AdminQuestRequest(
        @NotBlank @Size(max = 100) String title,
        @Size(max = 500) String description,
        @NotNull QuestGrade grade,
        @NotNull QuestCadence cadence,
        @NotNull CompletionType completionType,
        @Positive int expReward,
        @Size(max = 100) String placeName,
        BigDecimal latitude,
        BigDecimal longitude,
        Integer radiusM,
        Long lifedexItemId,
        Boolean active) {
}
