package com.lifequest.proof.dto;

import java.util.List;

/**
 * 커서 페이징 응답.
 *
 * @param nextCursor 다음 페이지 요청에 그대로 넣을 값. {@code null}이면 마지막 페이지다.
 *                   요청한 크기만큼 채워졌을 때만 채우므로, 앱은 이 값의 유무만 보고
 *                   무한 스크롤을 멈출지 정하면 된다
 */
public record ProofFeedResponse(List<ProofPostResponse> items, Long nextCursor) {
}
