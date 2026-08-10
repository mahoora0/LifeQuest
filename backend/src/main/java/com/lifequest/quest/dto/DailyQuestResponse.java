package com.lifequest.quest.dto;

import com.lifequest.quest.domain.DailyQuestStatus;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.domain.UserDailyQuest;

import java.math.BigDecimal;

/**
 * 배정 1건. 완료 요청이 지목하는 것은 퀘스트 원본이 아니라 이 {@code dailyQuestId}다
 * (docs/04-api-spec.md §4).
 *
 * <p>{@code questId}를 바깥에도 두고 요약을 중첩으로도 싣는다 — 계약(§3)이 두 값을 나란히
 * 요구하고, 앱은 중첩과 평탄화를 모두 받도록 되어 있다.
 *
 * <p>{@code distanceM}은 {@code GET /quests/nearby}에만 담긴다. 목록 조회는 사용자 좌표를
 * 받지 않으므로 채울 근거가 없고, 0을 넣으면 앱이 "바로 앞"으로 읽는다.
 */
public record DailyQuestResponse(
    Long dailyQuestId,
    Long questId,
    DailyQuestStatus status,
    QuestSummaryResponse quest,
    BigDecimal distanceM) {

    public static DailyQuestResponse of(UserDailyQuest assignment, Quest quest) {
        return of(assignment, quest, null);
    }

    public static DailyQuestResponse of(UserDailyQuest assignment, Quest quest, BigDecimal distanceM) {
        return new DailyQuestResponse(
            assignment.getId(),
            quest.getId(),
            assignment.getStatus(),
            // 원본이 아니라 배정 맥락으로 싣는다 — 템플릿 퀘스트는 좌표·장소명이 이 배정에만
            // 붙어 있고, 그것이 지도에 찍히는 지점이자 완료가 판정하는 지점이다(V32)
            QuestSummaryResponse.of(assignment, quest),
            distanceM);
    }
}
