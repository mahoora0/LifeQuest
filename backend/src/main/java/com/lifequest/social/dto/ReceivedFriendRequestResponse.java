package com.lifequest.social.dto;

import com.lifequest.social.FriendRequest;
import com.lifequest.social.FriendRequestStatus;
import java.time.Instant;

// 친구 요청 수신 정보를 나타내는 DTO
public record ReceivedFriendRequestResponse(
        Long requestId,
        Long senderId,
        String senderNickname,
        String senderProfileImageUrl,
        int senderLevel,
        int senderTotalExp,
        FriendRequestStatus status,
        Instant createdAt) {
    public static ReceivedFriendRequestResponse from(FriendRequest request) {
        return new ReceivedFriendRequestResponse(
                request.getId(),
                request.getSender().getId(),
                request.getSender().getNickname(),
                request.getSender().getProfileImageUrl(),
                request.getSender().getLevel(),
                request.getSender().getTotalExp(),
                request.getStatus(),
                request.getCreatedAt());
    }
}
