package com.lifequest.user.dto;

import com.lifequest.user.User;

public record UserSearchResponse(
        Long userId,
        String nickname,
        String profileImageUrl,
        int level,
        int totalExp
) {
    public static UserSearchResponse from(User user) {
        return new UserSearchResponse(
                user.getId(),
                user.getNickname(),
                user.getProfileImageUrl(),
                user.getLevel(),
                user.getTotalExp()
        );
    }
}