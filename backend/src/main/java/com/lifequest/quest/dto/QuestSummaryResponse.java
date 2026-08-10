package com.lifequest.quest.dto;

import com.lifequest.quest.domain.CompletionType;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.domain.QuestCreator;
import com.lifequest.quest.domain.QuestGrade;
import com.lifequest.quest.domain.UserDailyQuest;

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
    Integer radiusM,
    String completionGuide,
    QuestCreator createdBy) {

    /**
     * 배정과 무관한 퀘스트 원본. {@code GET /quests/{questId}} 상세가 쓴다.
     *
     * <p>장소 미지정 템플릿(V33)을 이 팩토리로 실으면 좌표가 자리표 그대로 나간다. 상세는
     * 배정을 지목하지 않아 어느 사용자의 지점인지 알 수 없으므로 그것이 맞다 — 배정 화면과
     * 지도는 아래 {@link #of}를 지난다.
     */
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
            quest.getRadiusM(),
            quest.getCompletionGuide(),
            quest.getCreatedBy());
    }

    /**
     * 배정 맥락의 퀘스트 요약. 좌표·장소명은 그 배정에 붙은 값이 있으면 그것을 싣는다(V32).
     *
     * <p>화면이 보는 좌표와 완료 판정이 쓰는 좌표는 같아야 한다. 둘 다
     * {@code UserDailyQuest.resolvedLatitude} 계열을 지나므로 여기서 고르지 않는다 —
     * 고르는 자리가 둘이면 한쪽이 빠져도 컴파일과 테스트가 통과한다.
     *
     * <p>반경은 원본 값 그대로다. 인증 반경은 장소의 성격이 정하는 값이고 override 대상이 아니다.
     */
    public static QuestSummaryResponse of(UserDailyQuest assignment, Quest quest) {
        return new QuestSummaryResponse(
            quest.getId(),
            quest.getTitle(),
            quest.getDescription(),
            quest.getGrade(),
            quest.getCadence(),
            quest.getCompletionType(),
            quest.getExpReward(),
            assignment.resolvedPlaceName(quest),
            assignment.resolvedLatitude(quest),
            assignment.resolvedLongitude(quest),
            quest.getRadiusM(),
            quest.getCompletionGuide(),
            quest.getCreatedBy());
    }
}
