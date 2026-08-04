package com.lifequest.social.dto;

import com.lifequest.social.Friendship;
import java.util.List;
import org.springframework.data.domain.Page;

// 친구 목록과 페이지 정보를 함께 반환하는 DTO
public record FriendPageResponse(
        List<FriendResponse> content,
        int page,
        int size,
        long totalElements,
        int totalPages) {

    public static FriendPageResponse from(Page<Friendship> result) {
        return new FriendPageResponse(
                result.getContent().stream()
                        .map(FriendResponse::from)
                        .toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements(),
                result.getTotalPages());
    }
}
