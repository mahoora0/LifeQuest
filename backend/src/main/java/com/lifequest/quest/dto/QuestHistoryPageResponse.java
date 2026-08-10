package com.lifequest.quest.dto;

import java.util.List;
import org.springframework.data.domain.Page;

public record QuestHistoryPageResponse(
        List<QuestHistoryItemResponse> content,
        int page,
        int size,
        long totalElements,
        int totalPages,
        boolean last) {

    public static QuestHistoryPageResponse from(Page<QuestHistoryItemResponse> result) {
        return new QuestHistoryPageResponse(
                result.getContent(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements(),
                result.getTotalPages(),
                result.isLast());
    }
}
