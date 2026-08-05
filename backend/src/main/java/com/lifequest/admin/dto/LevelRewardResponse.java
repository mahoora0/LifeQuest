package com.lifequest.admin.dto;

import com.lifequest.growth.LevelReward;

public record LevelRewardResponse(
        Long id,
        int level,
        LevelReward.RewardType rewardType,
        Long rewardRefId,
        String rewardCode,
        String rewardName,
        String description) {
    public static LevelRewardResponse of(
            LevelReward reward, String rewardCode, String rewardName) {
        return new LevelRewardResponse(
                reward.getId(), reward.getLevel(), reward.getRewardType(),
                reward.getRewardRefId(), rewardCode, rewardName, reward.getDescription());
    }
}
