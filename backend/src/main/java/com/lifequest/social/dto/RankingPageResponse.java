package com.lifequest.social.dto;

import com.lifequest.user.User;
import java.util.ArrayList;
import java.util.List;
import org.springframework.data.domain.Page;

// EXP 랭킹 목록과 페이지 정보
public record RankingPageResponse(
        List<RankingEntryResponse> content,
        int page,
        int size,
        long totalElements,
        int totalPages) {

    public static RankingPageResponse from(Page<User> result, Long currentUserId) {
        long firstRank = result.getPageable().getOffset() + 1;
        List<RankingEntryResponse> entries = new ArrayList<>(result.getNumberOfElements());
        for (int index = 0; index < result.getNumberOfElements(); index++) {
            entries.add(RankingEntryResponse.from(
                    result.getContent().get(index),
                    firstRank + index,
                    currentUserId));
        }
        return new RankingPageResponse(
                List.copyOf(entries),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements(),
                result.getTotalPages());
    }
}
