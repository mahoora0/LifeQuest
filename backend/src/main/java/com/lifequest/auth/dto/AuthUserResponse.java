package com.lifequest.auth.dto;

import com.lifequest.user.User;

public record AuthUserResponse(
        Long id,
        String email,
        String nickname,
        String profileImageUrl,
        String role) {

    public static AuthUserResponse from(User user) {
        return new AuthUserResponse(
                user.getId(),
                user.getEmail(),
                user.getNickname(),
                user.getProfileImageUrl(),
                user.getRole().name());
    }
}
