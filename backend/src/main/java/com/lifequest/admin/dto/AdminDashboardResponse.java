package com.lifequest.admin.dto;

import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;

public record AdminDashboardResponse(
        long totalUsers,
        long activeQuests,
        long totalQuests,
        long totalCompletions,
        long todayCompletions,
        long totalExpGranted,
        long dailyQuests,
        long weeklyQuests,
        List<RecentUser> recentUsers,
        List<RecentCompletion> recentCompletions,
        List<RecentExp> recentExp,
        List<PopularQuest> popularQuests) {

    public record RecentUser(Long id, String nickname, String email, int level, Instant createdAt) {}
    public record RecentCompletion(Long userId, String nickname, Long questId, String questTitle,
                                   int expReward, LocalDateTime completedAt) {}
    public record RecentExp(Long userId, String nickname, String sourceType, int amount, Instant createdAt) {}
    public record PopularQuest(Long questId, String title, long completions) {}
}
