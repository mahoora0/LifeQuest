package com.lifequest.admin.dto;

import com.lifequest.quest.domain.DailyQuestStatus;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.user.UserRole;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

public record AdminUserDetailResponse(
        Long id, String nickname, String email, String profileImageUrl, UserRole role,
        int level, int totalExp, String representativeTitle, String representativeBadge,
        Instant createdAt, long completedQuestCount, long assignedQuestCount,
        List<QuestActivity> recentQuests, List<ExpActivity> recentExp) {

    public record QuestActivity(Long assignmentId, Long questId, String title,
                                QuestCadence cadence, int expReward, DailyQuestStatus status,
                                LocalDate assignedDate, LocalDateTime completedAt) {}

    public record ExpActivity(Long id, String sourceType, Long sourceId,
                              String description, int amount, Instant createdAt) {}
}
