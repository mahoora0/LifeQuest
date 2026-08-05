package com.lifequest.proof;

/** 피드 상단 세그먼트. 기본값은 {@link #NEEDS_VOTE}다. */
public enum ProofFeedTab {
    /**
     * 내가 아직 투표하지 않은, 판정 전인 남의 게시물을 오래된 순으로. 홈 섹션도 이걸 쓴다.
     * 이 탭이 기본인 이유는 사용자 수가 적을 때 최신순 피드가 표를 필요로 하는 게시물을
     * 아래로 밀어내기 때문이다.
     */
    NEEDS_VOTE,
    /** 전체 게시물 최신순. */
    ALL,
    /** 내가 올린 게시물 최신순. 판정 결과를 확인하는 자리다. */
    MINE
}
