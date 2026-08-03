package com.lifequest.collection;

/**
 * 퀘스트 완료 트랜잭션에 참여하는 LifeDex·업적 판정 서비스(팀원 3 소유, {@code docs/06-team-roles.md} §완료
 * 응답 필드 분배). 완료 트랜잭션을 여는 쪽(팀원 2)이 이 인터페이스를 호출하고, 실제 판정 로직은 구현체가
 * 담당한다.
 */
public interface CollectionService {

    /**
     * 퀘스트 완료 직후(중복 완료가 아닐 때만) 호출한다. 도감 등록·업적 조건 충족을 판정하고 새로 얻은
     * 것만 돌려준다.
     *
     * @param lifedexItemId {@code Quest.lifedexItemId} — 이 퀘스트 완료로 자동 등록될 도감 항목. 없으면 {@code null}
     */
    // TODO(팀원3): 업적 단계 보상(ACHIEVEMENT_STEPS.reward_title_id)을 지급하게 되면, 그 보상을
    // 응답 growth.rewards에 실을 방법이 지금 없다(CollectionOutcome은 해금 여부만 나른다).
    // QuestCompletionServiceImpl의 호출부 주석 참고 — 인터페이스 확장이 필요할 수 있다.
    CollectionOutcome evaluateOnQuestCompletion(
            Long userId, Long questId, Long lifedexItemId, Long questCompletionId);
}
