package com.lifequest.social.dto;

import com.lifequest.social.Friendship;
import java.time.Instant;

// 친구 목록의 공개 프로필 한 건을 나타내는 DTO
public record FriendResponse(
        Long userId,
        String nickname,
        String profileImageUrl,
        int level,
        int totalExp,
        Instant friendsSince) {

    public static FriendResponse from(Friendship friendship) {
        return new FriendResponse(
                friendship.getFriend().getId(),
                friendship.getFriend().getNickname(),
                friendship.getFriend().getProfileImageUrl(),
                friendship.getFriend().getLevel(),
                friendship.getFriend().getTotalExp(),
                friendship.getCreatedAt());
    }
}
