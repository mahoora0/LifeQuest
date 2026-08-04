package com.lifequest.social.dto;

import com.lifequest.social.FriendRequest;
import com.lifequest.social.FriendRequestStatus;
import java.time.Instant;

// 친구 요청 전송 응답을 나타내는 DTO
public record SendFriendRequestResponse(
        Long requestId,
        FriendRequestStatus status,
        Instant createdAt) {
    public static SendFriendRequestResponse from(FriendRequest request) {
        return new SendFriendRequestResponse(
                request.getId(),
                request.getStatus(),
                request.getCreatedAt());
    }
}
