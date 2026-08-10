package com.lifequest.social.dto;

import com.lifequest.user.User;

// 친구의 공개 프로필과 나란히 비교할 활동 요약
public record FriendProfileResponse(
        Long userId,
        String nickname,
        String profileImageUrl,
        String representativeTitle,
        FriendActivitySummary me,
        FriendActivitySummary friend) {

    public static FriendProfileResponse of(
            User friend,
            FriendActivitySummary me,
            FriendActivitySummary friendSummary) {
        return new FriendProfileResponse(
                friend.getId(),
                friend.getNickname(),
                friend.getProfileImageUrl(),
                friend.getRepresentativeTitle() == null
                        ? null
                        : friend.getRepresentativeTitle().getName(),
                me,
                friendSummary);
    }
}
