package com.lifequest.quest.domain;

/**
 * 퀘스트 반복 주기. 퀘스트 목록의 조회 필터 기준이며 완료 방식({@link CompletionType})과는 별개의 축이다
 * — 주간 퀘스트가 위치 인증일 수도, 일간 퀘스트가 직접 완료일 수도 있다.
 *
 * <p>현재는 카탈로그 분류에 한정된다. 주기에 따라 배정 간격이나 만료 시각을 다르게 둘지는
 * 배정 서비스 구현 시점에 확정한다.
 */
public enum QuestCadence {
    DAILY,
    WEEKLY,
    MONTHLY
}
