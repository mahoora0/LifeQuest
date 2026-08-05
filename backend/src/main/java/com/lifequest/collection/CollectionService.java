package com.lifequest.collection;

/**
 * 퀘스트 완료 트랜잭션에 참여하는 LifeDex·업적 판정 서비스(팀원 3 소유, {@code docs/06-team-roles.md} §완료
 * 응답 필드 분배). 완료 트랜잭션을 여는 쪽(팀원 2)이 이 인터페이스를 호출하고, 실제 판정 로직은 구현체가
 * 담당한다.
 *
 * <p><b>구현 시 지켜야 할 계약 셋.</b>
 *
 * <ol>
 *   <li><b>예외를 던지면 퀘스트 완료 자체가 롤백된다.</b> 이 메서드는 팀원 2가 여는 하나의 서버 트랜잭션
 *       안에서 호출된다({@code docs/06-team-roles.md} §완료 트랜잭션 규칙). 도감·업적 판정에서 올라온
 *       예외는 {@code QUEST_COMPLETIONS} 기록과 EXP 지급까지 되돌리므로, 사용자는 퀘스트를 완료하지 못한
 *       것이 된다. 판정 실패가 완료를 막을 사유가 아니라면 구현체 안에서 처리하고 빈 결과를 돌려준다.
 *   <li><b>업적 단계 보상은 {@code Entry.reward}에 싣는다.</b> {@code ACHIEVEMENT_STEPS.reward_title_id}를
 *       지급했다면 그 결과를 해당 업적 항목의 {@code reward}에 담는다 — 어느 업적이 준 보상인지 대응이
 *       남아야 한다. 지급이 아직 구현되지 않았다면 {@code null}로 두어도 응답은 유효하므로, 해금을 먼저
 *       붙이고 보상을 나중에 채울 수 있다. 완료 응답의 {@code growth.rewards}는 레벨업 보상 전용이니
 *       그쪽에 합치지 않는다({@code docs/06-team-roles.md} 역할 표 — {@code growth}는 팀원 1 소유).
 *       <p>지급 수단은 둘이고 응답 모양은 어느 쪽이든 같다. ⓐ 팀원 1이 {@code RewardService}에 특정 칭호를
 *       지급하는 공개 메서드를 열면 중복 지급 방지와 대표 칭호 자동 설정이 재사용된다. ⓑ
 *       {@code UserTitleRepository}를 직접 쓰면 {@code UserTitle}이 출처 인자를 이미 받으므로
 *       {@code "ACHIEVEMENT"}로 저장할 수 있고 스키마 변경이 없으나, 앞의 두 로직은 직접 처리해야 한다.
 *   <li><b>시그니처를 바꾸지 않는다.</b> 완료 응답 계약은 팀원 2 소유다. 반환 타입에 필드가 필요해지면
 *       먼저 담당자와 합의한다 — 임의 확장은 {@code QuestCompletionServiceImpl}의 배선과 완료 계약
 *       테스트를 동시에 깨뜨린다.
 * </ol>
 */
public interface CollectionService {

    /**
     * 퀘스트 완료 직후(중복 완료가 아닐 때만) 호출한다. 도감 등록·업적 조건 충족을 판정하고 새로 얻은
     * 것만 돌려준다.
     *
     * @param lifedexItemId {@code Quest.lifedexItemId} — 이 퀘스트 완료로 자동 등록될 도감 항목. 없으면 {@code null}
     */
    CollectionOutcome evaluateOnQuestCompletion(
            Long userId, Long questId, Long lifedexItemId, Long questCompletionId);
}
