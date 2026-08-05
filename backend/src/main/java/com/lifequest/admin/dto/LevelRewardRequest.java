package com.lifequest.admin.dto;

import com.lifequest.growth.LevelReward;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record LevelRewardRequest(
        @Min(1) @Max(1000) int level,
        @NotNull LevelReward.RewardType rewardType,
        @NotNull Long rewardRefId,
        @Size(max = 255) String description) {
}
