package com.lifequest.proof.dto;

/**
 * 투표 결과. 갱신된 게시물을 함께 돌려주므로 앱이 투표 후 카드를 다시 조회하지 않는다.
 *
 * @param expGained 이번 투표로 받은 EXP. 하루 한도를 넘겼으면 {@code 0}이고, 앱은 이 값이
 *                  0인지로 "오늘 투표 보상을 다 받았어요" 안내를 띄울지 정한다
 */
public record ProofVoteResponse(ProofPostResponse post, int expGained) {
}
