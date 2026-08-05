package com.lifequest.admin.dto;

import com.lifequest.quest.domain.Quest;
import java.util.List;
import org.springframework.data.domain.Page;

public record AdminQuestPageResponse(
        List<AdminQuestResponse> content,
        int page,
        int size,
        long totalElements,
        int totalPages) {
    public static AdminQuestPageResponse from(Page<Quest> quests) {
        return new AdminQuestPageResponse(
                quests.getContent().stream().map(AdminQuestResponse::from).toList(),
                quests.getNumber(), quests.getSize(), quests.getTotalElements(), quests.getTotalPages());
    }
}
