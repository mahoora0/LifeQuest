package com.lifequest.growth;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "level_rewards")
public class LevelReward {

    public enum RewardType {
        TITLE, PROFILE_ITEM
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private int level;

    @Enumerated(EnumType.STRING)
    @Column(name = "reward_type", nullable = false, length = 20)
    private RewardType rewardType;

    @Column(name = "reward_ref_id", nullable = false)
    private Long rewardRefId;

    @Column(length = 255)
    private String description;

    protected LevelReward() {
    }

    public Long getId() {
        return id;
    }

    public int getLevel() {
        return level;
    }

    public RewardType getRewardType() {
        return rewardType;
    }

    public Long getRewardRefId() {
        return rewardRefId;
    }
}
