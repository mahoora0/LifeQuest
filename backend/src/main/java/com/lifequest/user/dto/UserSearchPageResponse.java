package com.lifequest.user.dto;

import java.util.List;
import org.springframework.data.domain.Page;

// 사용자 검색 결과 목록과 페이지 정보를 함께 반환하는 DTO
public record UserSearchPageResponse(
                List<UserSearchResponse> content,
                int page,
                int size,
                long totalElements,
                int totalPages) {
        public static UserSearchPageResponse from(
                        Page<UserSearchResponse> result) {
                return new UserSearchPageResponse(
                                result.getContent(),
                                result.getNumber(),
                                result.getSize(),
                                result.getTotalElements(),
                                result.getTotalPages());
        }
}