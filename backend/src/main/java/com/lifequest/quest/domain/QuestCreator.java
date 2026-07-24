package com.lifequest.quest.domain;

/**
 * 퀘스트 생성 주체. ADMIN 등록분도 일반 퀘스트와 동일하게 배정 풀에 포함된다
 * (docs/05-business-rules.md §11).
 */
public enum QuestCreator {
    SYSTEM,
    ADMIN
}
