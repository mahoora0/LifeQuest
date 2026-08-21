package com.lifequest.quest.service;

import static org.junit.jupiter.api.Assertions.assertEquals;

import com.lifequest.quest.domain.QuestCategory;
import com.lifequest.recommendation.RecommendationCategory;
import java.util.Map;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

class WeeklyAiQuestCategoryMappingTest {

    private static final Map<RecommendationCategory, QuestCategory> EXPECTED = Map.of(
            RecommendationCategory.FOOD, QuestCategory.FOOD_CAFE,
            RecommendationCategory.CAFE, QuestCategory.FOOD_CAFE,
            RecommendationCategory.WALK, QuestCategory.NATURE_OUTDOOR,
            RecommendationCategory.NATURE, QuestCategory.NATURE_OUTDOOR,
            RecommendationCategory.CULTURE, QuestCategory.CULTURE_TRAVEL,
            RecommendationCategory.TRAVEL, QuestCategory.CULTURE_TRAVEL,
            RecommendationCategory.EXERCISE, QuestCategory.HEALTH_FITNESS,
            RecommendationCategory.EXPERIENCE, QuestCategory.ETC);

    @ParameterizedTest
    @EnumSource(RecommendationCategory.class)
    void 추천_카테고리_전체가_퀘스트_대표_주제로_변환된다(RecommendationCategory source) {
        assertEquals(EXPECTED.get(source), WeeklyAiQuestService.questCategory(source));
    }
}
