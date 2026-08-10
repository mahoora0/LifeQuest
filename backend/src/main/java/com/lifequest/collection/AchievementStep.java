package com.lifequest.collection;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "achievement_steps")
class AchievementStep {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "achievement_id", nullable = false)
    private Long achievementId;

    @Column(name = "step_no", nullable = false)
    private int stepNo;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(name = "required_count", nullable = false)
    private int requiredCount;

    @Column(name = "reward_title_id")
    private Long rewardTitleId;

    protected AchievementStep() {
    }

    Long getId() {
        return id;
    }

    Long getAchievementId() {
        return achievementId;
    }

    int getStepNo() {
        return stepNo;
    }

    String getName() {
        return name;
    }

    int getRequiredCount() {
        return requiredCount;
    }

    Long getRewardTitleId() {
        return rewardTitleId;
    }
}
