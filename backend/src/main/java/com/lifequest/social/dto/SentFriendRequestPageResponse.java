package com.lifequest.social.dto;

import com.lifequest.social.FriendRequest;
import java.util.List;
import org.springframework.data.domain.Page;

public record SentFriendRequestPageResponse(
        List<SentFriendRequestResponse> content,
        int page,
        int size,
        long totalElements,
        int totalPages) {
    public static SentFriendRequestPageResponse from(Page<FriendRequest> result) {
        return new SentFriendRequestPageResponse(
                result.getContent().stream().map(SentFriendRequestResponse::from).toList(),
                result.getNumber(), result.getSize(),
                result.getTotalElements(), result.getTotalPages());
    }
}
