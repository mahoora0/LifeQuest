package com.lifequest.quest.dto;

import java.math.BigDecimal;

/**
 * 퀘스트 완료 요청 본문.
 *
 * <p>{@code completion_type = LOCATION}인 퀘스트에만 필요하다. {@code SELF_REPORT}
 * 퀘스트는 본문 없이 호출하므로 모든 필드가 비어 있을 수 있고, 컨트롤러도 본문
 * 자체를 요구하지 않는다({@code docs/04-api-spec.md} §4).
 *
 * <p>검증을 어노테이션이 아니라 서비스에서 하는 이유 — 좌표가 필요한지 여부가
 * 요청이 아니라 대상 퀘스트의 {@code completion_type}에 달려 있다. 본문만 보고는
 * 빈 값이 규약 위반인지 정상인지 판단할 수 없다. 빠진 경우의 응답도 일반
 * 검증 실패가 아니라 {@code LOCATION_REQUIRED}로 구분해서 나가야 한다.
 *
 * <p>좌표를 {@code double}이 아니라 {@link BigDecimal}로 받는다. 저장 컬럼이
 * {@code DECIMAL(10,7)}이라 그대로 넣을 수 있고, 거리 계산에서만 실수로 바꾼다.
 */
public record QuestCompletionRequest(
    BigDecimal latitude,
    BigDecimal longitude,
    BigDecimal accuracy) {

    /**
     * 위치 검증에 필요한 세 값이 모두 있는지. 하나라도 없으면 검증을 시작할 수 없다.
     */
    public boolean hasLocation() {
        return latitude != null && longitude != null && accuracy != null;
    }

    public boolean isCoordinatesValid() {
        if (latitude == null || longitude == null) {
            return false;
        }

        return latitude.compareTo(BigDecimal.valueOf(-90)) >= 0 &&
            latitude.compareTo(BigDecimal.valueOf(90)) <= 0 &&
            longitude.compareTo(BigDecimal.valueOf(-180)) >= 0 &&
            longitude.compareTo(BigDecimal.valueOf(180)) <= 0;
    }
}
