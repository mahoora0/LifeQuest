package com.lifequest.quest.domain;

/**
 * 퀘스트 반복 주기. 퀘스트 목록의 조회 필터 기준이며 완료 방식({@link CompletionType})과는 별개의 축이다
 * — 주간 퀘스트가 위치 인증일 수도, 일간 퀘스트가 직접 완료일 수도 있다.
 *
 * <p>배정은 이 두 값을 <b>독립 트랙</b>으로 다룬다. 트랙마다 슬롯 수·갱신 주기·등급 확률이 따로이며
 * 한쪽이 비어도 다른 쪽 배정은 그대로 생성된다(docs/05-business-rules.md §1).
 *
 * <p>협동 퀘스트는 여기 없다. 협동은 시간 주기가 아니라 참여 형태이므로 {@code QuestFeature.COOP}이
 * 그 축을 따로 다룬다. 두 enum의 값 집합이 어긋나 보이는 것은 의도된 것이며, 협동의 갱신·만료 규칙이
 * 정해질 때 별도 축으로 설계한다.
 *
 * <p>MONTHLY는 V15에서 걷혔다. 월간으로 적재됐던 id 37~42는 주간으로 옮기거나 비활성으로 내렸다.
 */
public enum QuestCadence {
    DAILY,
    WEEKLY
}
