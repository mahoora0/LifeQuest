package com.lifequest.admin.dto;

public record DeactivateQuestResponse(Long questId, boolean deactivated) {
    public static DeactivateQuestResponse success(Long questId) {
        return new DeactivateQuestResponse(questId, true);
    }
}
