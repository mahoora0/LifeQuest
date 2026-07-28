package com.lifequest.user.dto;

import java.util.List;
import org.springframework.data.domain.Page;

public record UserSearchPageResponse(
        List<UserSearchResponse> content,
        int page,
        int size,
        long totalElements,
        int totalPages
) {
    public static UserSearchPageResponse from(
            Page<UserSearchResponse> result
    ) {
        return new UserSearchPageResponse(
                result.getContent(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements(),
                result.getTotalPages()
        );
    }
}