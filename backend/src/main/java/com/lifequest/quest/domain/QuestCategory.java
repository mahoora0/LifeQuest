package com.lifequest.quest.domain;

/**
 * 퀘스트의 대표 주제. 인증 광장 필터와 퀘스트 탐색이 함께 쓰는 분류다.
 *
 * <p>LifeDex 카테고리는 수집 대상 장소의 분류라 직접 완료 퀘스트를 포괄하지 못한다.
 * 한 퀘스트가 여러 필터에 중복 노출되지 않도록 대표 주제 하나만 둔다.
 */
public enum QuestCategory {
    HEALTH_FITNESS,
    DAILY_HABIT,
    LEARNING_GROWTH,
    RELATIONSHIP_COMMUNITY,
    FOOD_CAFE,
    NATURE_OUTDOOR,
    CULTURE_TRAVEL,
    ETC
}
