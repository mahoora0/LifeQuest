package com.lifequest.quest.dto;

import jakarta.validation.constraints.NotNull;

/** 주간 AI 슬롯 선택 요청. 후보 내용이 아니라 id만 받는다. */
public record ClaimWeeklyAiQuestRequest(@NotNull Long candidateId) {
}
