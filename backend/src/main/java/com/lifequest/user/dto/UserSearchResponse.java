package com.lifequest.user.dto;

import com.lifequest.user.User;

// 검색된 사용자 한 명의 공개 정보를 나타내는 DTO
public record UserSearchResponse(
        Long userId,
        String nickname,
        String profileImageUrl,
        int level,
        int totalExp) {
    public static UserSearchResponse from(User user) {
        return new UserSearchResponse(
                user.getId(),
                user.getNickname(),
                user.getProfileImageUrl(),
                user.getLevel(),
                user.getTotalExp());
    }
}