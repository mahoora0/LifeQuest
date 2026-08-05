package com.lifequest.social.dto;

import com.lifequest.social.FriendRequest;
import com.lifequest.social.FriendRequestStatus;
import java.time.Instant;

public record SentFriendRequestResponse(
        Long requestId,
        Long receiverId,
        String receiverNickname,
        String receiverProfileImageUrl,
        int receiverLevel,
        int receiverTotalExp,
        FriendRequestStatus status,
        Instant createdAt) {
    public static SentFriendRequestResponse from(FriendRequest request) {
        return new SentFriendRequestResponse(
                request.getId(), request.getReceiver().getId(),
                request.getReceiver().getNickname(), request.getReceiver().getProfileImageUrl(),
                request.getReceiver().getLevel(), request.getReceiver().getTotalExp(),
                request.getStatus(), request.getCreatedAt());
    }
}
