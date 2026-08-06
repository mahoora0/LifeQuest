package com.lifequest.quest.dto;

import java.time.LocalDate;
import java.util.List;

/**
 * {@code GET /quests/today} 응답(docs/04-api-spec.md §3).
 *
 * <p>{@code assignedDate}는 <b>조회 시점의 논리적 일자</b>이지 개별 배정의 {@code assignedDate}가
 * 아니다. 주간 배정은 그 주 월요일을 갖고 있어 트랙마다 값이 다르므로, 화면이 "오늘"로 쓸 수
 * 있는 날짜는 하나여야 한다(docs/05-business-rules.md §1-1의 04:00 경계 적용).
 */
public record TodayQuestsResponse(LocalDate assignedDate, List<DailyQuestResponse> quests) {
}
