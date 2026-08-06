package com.lifequest.proof;

/**
 * 투표 선택지. 화면 문구는 "인증 맞아요 / 판단하기 어려워요 / 인증이 아닌 것 같아요"이며
 * 클라이언트가 이 이름을 그대로 보낸다.
 */
public enum ProofVoteChoice {
    AGREE,
    UNSURE,
    REJECT
}
