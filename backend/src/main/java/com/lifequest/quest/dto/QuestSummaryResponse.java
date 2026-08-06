package com.lifequest.quest.dto;

import com.lifequest.quest.domain.CompletionType;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.domain.QuestGrade;

import java.math.BigDecimal;

/**
 * 퀘스트 원본 요약. {@code GET /quests/today}의 각 항목과 {@code GET /quests/{questId}} 상세가
 * 같은 모양을 쓴다(docs/04-api-spec.md §3).
 *
 * <p>좌표·반경은 {@code SELF_REPORT} 퀘스트에서 {@code null}이다. 앱은 <b>반경을 모르면
 * 클라이언트 판정을 건너뛰고 서버에 맡기도록</b> 되어 있으므로(`quest_dto.dart` {@code hasRadius}),
 * 값이 없을 때 임의의 기본값을 채워 보내면 안 된다 — 실제로는 인증 가능한 퀘스트를 앱이
 * 영구히 막아버릴 수 있다.
 */
public record QuestSummaryResponse(
    Long questId,
    String title,
    String description,
    QuestGrade grade,
    QuestCadence cadence,
    CompletionType completionType,
    int expReward,
    String placeName,
    BigDecimal latitude,
    BigDecimal longitude,
    Integer radiusM) {

    public static QuestSummaryResponse from(Quest quest) {
        return new QuestSummaryResponse(
            quest.getId(),
            quest.getTitle(),
            quest.getDescription(),
            quest.getGrade(),
            quest.getCadence(),
            quest.getCompletionType(),
            quest.getExpReward(),
            quest.getPlaceName(),
            quest.getLatitude(),
            quest.getLongitude(),
            quest.getRadiusM());
    }
}
