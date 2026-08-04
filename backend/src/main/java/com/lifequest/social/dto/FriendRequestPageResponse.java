package com.lifequest.social.dto;

import com.lifequest.social.FriendRequest;
import java.util.List;
import org.springframework.data.domain.Page;

// 친구 요청 페이지 응답을 나타내는 DTO
public record FriendRequestPageResponse(
                List<ReceivedFriendRequestResponse> content,
                int page,
                int size,
                long totalElements,
                int totalPages) {
        public static FriendRequestPageResponse from(Page<FriendRequest> result) {
                return new FriendRequestPageResponse(
                                result.getContent().stream()
                                                .map(ReceivedFriendRequestResponse::from)
                                                .toList(),
                                result.getNumber(),
                                result.getSize(),
                                result.getTotalElements(),
                                result.getTotalPages());
        }
}
