package com.lifequest.proof;

/**
 * 인증 게시물의 판정 상태.
 *
 * <p>판정은 투표가 들어올 때마다 같은 트랜잭션에서 다시 계산한다. 만료 배치가 없다는 뜻이고,
 * 그래서 확정된 뒤에 표가 더 모이면 상태가 다시 바뀔 수 있다. 사용자가 3명뿐인 환경에서
 * 표를 오래 모아야 하는 것이 정상이라 "한 번 확정되면 끝"보다 이쪽이 맞다.
 */
public enum ProofPostStatus {
    /** 아직 판정에 필요한 표가 모이지 않았다. */
    VOTING,
    /** 인증 완료. */
    VERIFIED,
    /** 표는 모였지만 의견이 갈렸다. */
    UNCLEAR,
    /** 퀘스트 수행으로 보기 어렵다는 쪽이 우세하다. */
    REJECTED;

    /**
     * {@code UNSURE}는 분모에서 뺀다. "판단하기 어려워요"를 반대표로 세면 사진이 애매한 것과
     * 퀘스트를 안 한 것이 같은 취급을 받고, 찬성표로 세면 아무 정보 없는 표가 인증을 만든다.
     * 어느 쪽도 판정 근거가 아니므로 모수에서 제외하는 것이 유일하게 일관된 처리다.
     *
     * @param agree          인증 맞아요 표 수
     * @param reject         인증이 아닌 것 같아요 표 수
     * @param minVotes       판정을 시작할 최소 유효 표 수(UNSURE 제외)
     * @param agreeThreshold 이 비율 이상이면 VERIFIED
     * @param unclearFloor   이 비율 미만이면 REJECTED
     */
    static ProofPostStatus of(
            int agree,
            int reject,
            int minVotes,
            double agreeThreshold,
            double unclearFloor) {

        int decided = agree + reject;
        if (decided < minVotes) {
            return VOTING;
        }

        double agreeRatio = (double) agree / decided;
        if (agreeRatio >= agreeThreshold) {
            return VERIFIED;
        }
        return agreeRatio >= unclearFloor ? UNCLEAR : REJECTED;
    }
}
