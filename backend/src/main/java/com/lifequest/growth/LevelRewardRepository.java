package com.lifequest.growth;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface LevelRewardRepository extends JpaRepository<LevelReward, Long> {
    List<LevelReward> findAllByLevelBetweenOrderByLevelAscIdAsc(int fromLevel, int toLevel);

    List<LevelReward> findAllByRewardTypeOrderByLevelAscIdAsc(
            LevelReward.RewardType rewardType);
}
