package com.lifequest.collection;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDateTime;

@Entity
@Table(name = "user_achievements")
class UserAchievement {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "achievement_id", nullable = false)
    private Long achievementId;

    @Column(name = "current_value", nullable = false)
    private int currentValue;

    @Column(name = "current_step", nullable = false)
    private int currentStep;

    @Column(name = "achieved_at")
    private LocalDateTime achievedAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    protected UserAchievement() {
    }

    UserAchievement(Long userId, Long achievementId) {
        this.userId = userId;
        this.achievementId = achievementId;
        this.updatedAt = LocalDateTime.now();
    }

    void update(int currentValue, int currentStep, boolean completed, LocalDateTime now) {
        this.currentValue = currentValue;
        this.currentStep = currentStep;
        if (completed && achievedAt == null) {
            achievedAt = now;
        }
        this.updatedAt = now;
    }

    Long getAchievementId() {
        return achievementId;
    }

    int getCurrentStep() {
        return currentStep;
    }
}
