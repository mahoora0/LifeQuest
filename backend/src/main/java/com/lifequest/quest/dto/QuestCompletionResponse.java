package com.lifequest.quest.dto;

import com.lifequest.growth.RewardGrant;
import com.lifequest.quest.domain.QuestGrade;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 퀘스트 완료 응답. 계약 원본은 {@code docs/04-api-spec.md} §4다.
 *
 * <p>완료 한 번에 완료 기록·성장·수집이 함께 움직이고 그 결과를 한 응답으로 돌려준다.
 * 앱은 이 응답만으로 완료 결과 화면을 그린다 — 뒤이어 다시 조회하지 않는다.
 *
 * @param location {@code completion_type = LOCATION}인 경우에만 채운다. 그 외에는 {@code null}
 */
public record QuestCompletionResponse(
        Long completionId,
        Long dailyQuestId,
        Long questId,
        QuestGrade grade,
        LocalDateTime completedAt,
        boolean duplicated,
        Location location,
        Growth growth,
        CollectionResult collection) {

    /** 인증된 위치와 대상 지점 사이의 거리. 반경 밖 안내에서 현재 거리를 보여주는 근거다. */
    public record Location(BigDecimal distanceM, BigDecimal accuracyM) {
    }

    /**
     * 성장 결과. {@link com.lifequest.growth.GrowthResult}와 필드가 다르다 —
     * 그쪽은 서비스 간 전달용이라 {@code duplicated}를 담고 {@code totalExp}가 없다.
     * 응답에서 중복 여부는 최상위 {@code duplicated} 하나로만 나간다.
     */
    public record Growth(
            int expGained,
            int totalExp,
            int previousLevel,
            int currentLevel,
            boolean levelUp,
            List<RewardGrant> rewards) {
    }

    public record CollectionResult(
            List<Entry> newLifedexItems,
            List<Entry> newAchievements) {
    }

    /**
     * 새로 등록된 도감 항목 또는 해금된 업적.
     *
     * @param secret 비밀 업적인지. 앱은 이 값으로 완료 결과 위에 모달을 겹칠지 정한다(S-17).
     *               계약 예시에는 없던 필드지만 앱이 이미 읽고 있고, 빠지면 모달이 한 번도
     *               뜨지 않는다. 도감 항목에는 해당하지 않아 항상 {@code false}다.
     */
    public record Entry(Long id, String name, boolean secret) {
    }

    /**
     * 중복 완료 응답의 성장 부분.
     *
     * <p>계약은 이 경우 {@code expGained=0}, {@code previousLevel=currentLevel},
     * {@code levelUp=false}, 보상 배열은 빈 값이어야 한다고 규정한다. 호출부마다 이
     * 조합을 다시 쓰면 하나만 어긋나도 재지급한 것처럼 보이므로 여기에 모아 둔다.
     */
    public static Growth noGrowth(int totalExp, int currentLevel) {
        return new Growth(0, totalExp, currentLevel, currentLevel, false, List.of());
    }

    /** 중복 완료 응답의 수집 부분. 어떤 것도 새로 얻지 않았다. */
    public static CollectionResult nothingCollected() {
        return new CollectionResult(List.of(), List.of());
    }
}
