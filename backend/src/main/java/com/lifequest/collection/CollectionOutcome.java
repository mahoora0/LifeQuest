package com.lifequest.collection;

import java.util.List;

/**
 * 퀘스트 완료 한 번으로 새로 얻은 도감 항목·업적. {@code com.lifequest.quest.dto.QuestCompletionResponse
 * .CollectionResult}와 필드가 같아 보이지만, quest DTO를 그대로 반환하면 collection 모듈이 quest에
 * 역방향 의존하게 되어 전용 타입을 둔다(같은 이유로 {@code GrowthSnapshot}이 분리된 전례가 있다).
 */
public record CollectionOutcome(List<Entry> newLifedexItems, List<Entry> newAchievements) {

    /**
     * @param secret 비밀 업적인지. 도감 항목에는 해당하지 않아 항상 {@code false}.
     */
    public record Entry(Long id, String name, boolean secret) {
    }

    /** 아무것도 새로 얻지 않았을 때. */
    public static CollectionOutcome none() {
        return new CollectionOutcome(List.of(), List.of());
    }
}
