package com.lifequest.auth.dto;

public record AuthTokenResponse(
        String accessToken,
        String refreshToken,
        long expiresIn,
        AuthUserResponse user) {
}
