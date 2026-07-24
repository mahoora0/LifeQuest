package com.lifequest.auth.dto;

import com.lifequest.user.User;
import java.time.Instant;

public record SignupResponse(Long userId, String email, String nickname, Instant createdAt) {

    public static SignupResponse from(User user) {
        return new SignupResponse(
                user.getId(),
                user.getEmail(),
                user.getNickname(),
                user.getCreatedAt());
    }
}
