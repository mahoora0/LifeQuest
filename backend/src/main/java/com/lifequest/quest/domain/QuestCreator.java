package com.lifequest.quest.domain;

/**
 * 퀘스트 생성 주체. ADMIN 등록분도 일반 퀘스트와 동일하게 배정 풀에 포함된다
 * (docs/05-business-rules.md §11).
 *
 * <p>AI는 사용자가 추천 후보 중에서 고른 <b>개인 전용</b> 주간 퀘스트다. 배정 풀에는 들어가지
 * 않으며 그 사용자에게만 보인다. 다만 "개인 퀘스트인가"의 판정 기준은 이 값이 아니라
 * {@code Quest.ownerUserId}다 — 나중에 AI가 공용 카탈로그를 생성하게 되면 두 축이 갈린다.
 * 소유 여부를 물어야 하는 자리(배정 풀·상세 권한·어드민 목록)는 전부 ownerUserId를 본다.
 */
public enum QuestCreator {
    SYSTEM,
    ADMIN,
    AI
}
