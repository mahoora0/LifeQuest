package com.lifequest.quest.service;

import com.lifequest.quest.dto.QuestCompletionRequest;
import com.lifequest.quest.dto.QuestCompletionResponse;

/**
 * 퀘스트 완료 처리. 계약 원본은 {@code docs/04-api-spec.md} §4다.
 *
 * <p>인터페이스로 두는 이유는 구현을 갈아끼우기 위해서다. 서버가 아직 없는 구간을
 * 스텁으로 채우더라도 컨트롤러와 계약은 그대로 두고 구현체만 지우면 된다 —
 * 조건부 분기가 프로덕션 코드에 남지 않는다.
 *
 * <p>구현이 반드시 지켜야 하는 것:
 *
 * <ul>
 *   <li>배정 건의 소유권을 확인한 직후 <b>기존 완료 기록부터 조회</b>한다. 이미 완료된
 *       요청은 위치를 다시 검증하지 않는다 — 반경 밖으로 이동한 뒤 다시 눌러도
 *       이미 받은 완료가 취소되거나 오류가 되어서는 안 된다.
 *   <li>중복 완료는 오류가 아니라 <b>HTTP 200</b>이다. {@code duplicated=true}와 기존
 *       {@code completionId}를 돌려주고 EXP·도감·업적·보상 어느 것도 재지급하지 않는다.
 *   <li>신규 완료는 완료 기록·EXP 로그·사용자 EXP/레벨·레벨 보상·도감·업적 반영을
 *       <b>하나의 트랜잭션</b>으로 묶는다. 어느 단계든 실패하면 전체를 되돌린다.
 * </ul>
 *
 * <p>재지급 방어선은 두 겹이다. 1차는 {@code uk_quest_completions_udq}
 * ({@code UNIQUE(user_daily_quest_id)}), 2차는 {@code exp_logs}의
 * {@code UNIQUE(user_id, source_type, source_id)}다. 2차가 작동하려면 EXP 지급 시
 * {@code sourceId}에 <b>{@code completionId}</b>를 넘겨야 한다 — 배정 ID나 퀘스트 ID를
 * 넘기면 서로 다른 완료가 같은 근거로 묶여 정상 지급까지 막힌다.
 */
public interface QuestCompletionService {

    /**
     * 배정된 퀘스트 한 건을 완료 처리한다.
     *
     * @param userId       요청자. 배정 건의 소유자와 다르면 {@code RESOURCE_NOT_FOUND}로
     *                     응답한다 — 남의 배정이 존재한다는 사실 자체를 알리지 않는다
     * @param dailyQuestId 퀘스트 원본이 아니라 <b>배정</b> ID
     * @param request      위치 인증 정보. {@code SELF_REPORT} 퀘스트는 비어 있을 수 있다
     * @return 완료 결과. 중복 완료도 예외가 아니라 이 응답으로 돌아온다
     */
    QuestCompletionResponse complete(
            Long userId, Long dailyQuestId, QuestCompletionRequest request);
}
