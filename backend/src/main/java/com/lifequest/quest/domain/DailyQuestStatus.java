package com.lifequest.quest.domain;

/**
 * 배정 건(USER_DAILY_QUESTS)의 상태. 배정 → 완료 또는 만료로 전이한다.
 */
public enum DailyQuestStatus {
    ASSIGNED,
    COMPLETED,
    EXPIRED
}
