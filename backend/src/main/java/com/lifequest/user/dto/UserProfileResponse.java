package com.lifequest.user.dto;

import com.lifequest.user.User;

public record UserProfileResponse(
        Long id,
        String email,
        String nickname,
        String profileImageUrl,
        String role,
        Object representativeTitle) {

    public static UserProfileResponse from(User user) {
        return new UserProfileResponse(
                user.getId(),
                user.getEmail(),
                user.getNickname(),
                user.getProfileImageUrl(),
                user.getRole().name(),
                null);
    }
}
