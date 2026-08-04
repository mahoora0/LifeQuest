package com.lifequest.social.dto;

import com.lifequest.user.User;

// 친구 비교 화면에 공개할 수 있는 활동 요약
public record FriendActivitySummary(
        int level,
        int totalExp,
        long completedQuestCount,
        long visitedPlaceCount) {

    public static FriendActivitySummary of(
            User user,
            long completedQuestCount,
            long visitedPlaceCount) {
        return new FriendActivitySummary(
                user.getLevel(),
                user.getTotalExp(),
                completedQuestCount,
                visitedPlaceCount);
    }
}
