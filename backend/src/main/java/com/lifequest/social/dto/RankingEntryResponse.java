package com.lifequest.social.dto;

import com.lifequest.user.User;

// EXP 랭킹의 사용자 한 줄
public record RankingEntryResponse(
        long rank,
        Long userId,
        String nickname,
        String profileImageUrl,
        int level,
        int totalExp,
        boolean isMe) {

    public static RankingEntryResponse from(User user, long rank, Long currentUserId) {
        return new RankingEntryResponse(
                rank,
                user.getId(),
                user.getNickname(),
                user.getProfileImageUrl(),
                user.getLevel(),
                user.getTotalExp(),
                user.getId().equals(currentUserId));
    }
}
