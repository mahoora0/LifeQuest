package com.lifequest.social.dto;

import com.lifequest.social.FriendRequest;
import com.lifequest.social.FriendRequestStatus;
import java.time.Instant;

// 친구 요청 처리 응답을 나타내는 DTO
public record RespondFriendRequestResponse(
        Long requestId,
        FriendRequestStatus status,
        Instant respondedAt) {
    public static RespondFriendRequestResponse from(FriendRequest request) {
        return new RespondFriendRequestResponse(
                request.getId(),
                request.getStatus(),
                request.getRespondedAt());
    }
}
