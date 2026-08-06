package com.lifequest.proof;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

/**
 * 판정 규칙만 떼어 고정한다. 이 규칙은 DB도 스프링 컨텍스트도 필요 없는 순수 계산이라,
 * 경계값을 여기서 잡아 두면 통합 테스트가 흐름만 확인하면 된다.
 */
class ProofPostStatusTests {

    private static final int MIN_VOTES = 3;
    private static final double AGREE_THRESHOLD = 0.70;
    private static final double UNCLEAR_FLOOR = 0.40;

    private static ProofPostStatus judge(int agree, int reject) {
        return ProofPostStatus.of(agree, reject, MIN_VOTES, AGREE_THRESHOLD, UNCLEAR_FLOOR);
    }

    @Test
    void 유효표가_기준에_못_미치면_계속_투표_중이다() {
        assertThat(judge(0, 0)).isEqualTo(ProofPostStatus.VOTING);
        assertThat(judge(2, 0)).isEqualTo(ProofPostStatus.VOTING);
        assertThat(judge(1, 1)).isEqualTo(ProofPostStatus.VOTING);
    }

    @Test
    void 판단하기_어려워요는_유효표에서_빠진다() {
        // UNSURE는 애초에 이 함수로 들어오지 않는다. 찬성 2 + 모르겠음 10이라도
        // 유효표는 2뿐이므로 판정이 시작되지 않아야 한다.
        assertThat(judge(2, 0)).isEqualTo(ProofPostStatus.VOTING);
    }

    @Test
    void 찬성_비율이_기준_이상이면_인증된다() {
        assertThat(judge(3, 0)).isEqualTo(ProofPostStatus.VERIFIED);
        // 7/10 = 0.70, 임계값 경계는 인증 쪽에 포함된다.
        assertThat(judge(7, 3)).isEqualTo(ProofPostStatus.VERIFIED);
    }

    @Test
    void 의견이_갈리면_보류다() {
        // 2/3 = 0.667 — 인증 임계에는 못 미치고 하한은 넘는다.
        assertThat(judge(2, 1)).isEqualTo(ProofPostStatus.UNCLEAR);
        // 4/10 = 0.40, 하한 경계는 보류 쪽에 포함된다.
        assertThat(judge(4, 6)).isEqualTo(ProofPostStatus.UNCLEAR);
    }

    @Test
    void 반대가_우세하면_인증이_거절된다() {
        assertThat(judge(0, 3)).isEqualTo(ProofPostStatus.REJECTED);
        // 3/10 = 0.30 — 하한 미만.
        assertThat(judge(3, 7)).isEqualTo(ProofPostStatus.REJECTED);
    }

    @Test
    void 표가_더_모이면_판정이_다시_바뀔_수_있다() {
        // 만료 배치가 없다는 설계의 결과다. 인증된 뒤 반대표가 쌓이면 보류로 내려간다.
        assertThat(judge(3, 0)).isEqualTo(ProofPostStatus.VERIFIED);
        assertThat(judge(3, 2)).isEqualTo(ProofPostStatus.UNCLEAR);
    }
}
