package com.lifequest.recommendation;

import com.lifequest.common.exception.ErrorCode;

/**
 * 주간 AI 슬롯 상태. 앱이 <b>추천을 시작하기 전에</b> 물어본다.
 *
 * <p>이것이 없으면 두 가지가 어긋난다. 이미 받은 사용자가 추천 화면까지 들어가 LLM 비용을
 * 쓰고 마지막에 409를 만나고, 여행 폼이 기본 2일을 고른 채 논리적 일요일(남은 1일)에 제출해
 * 검증 실패를 본다.
 *
 * @param available     지금 받을 수 있는가
 * @param reason        받을 수 없는 이유. 받을 수 있으면 {@code null}
 * @param remainingDays 이번 주기에 남은 논리적 일수(최소 1). 여행 기간 상한이다
 */
public record WeeklyAiQuestStatus(boolean available, String reason, int remainingDays) {

    WeeklyAiQuestStatus(boolean available, ErrorCode reason, int remainingDays) {
        this(available, reason == null ? null : reason.code(), remainingDays);
    }
}
