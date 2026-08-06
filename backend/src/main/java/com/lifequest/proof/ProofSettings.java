package com.lifequest.proof;

/**
 * 인증 광장의 밸런싱 값. 전부 {@code application.yml}의 {@code app.proof.*}에서 온다.
 *
 * <p>{@code minVotes}를 설정으로 뺀 이유가 실질적이다 — 개발·시연 환경의 사용자는 몇 명뿐이라
 * 3표 기준으로는 어떤 게시물도 판정에 도달하지 못한다. 로컬에서 1로 낮추면 계정을 여러 개
 * 만들지 않고도 전체 흐름을 확인할 수 있다.
 *
 * @param minVotes           판정을 시작할 최소 유효 표 수(UNSURE 제외)
 * @param agreeThreshold     VERIFIED가 되는 찬성 비율
 * @param unclearFloor       이 비율 미만이면 REJECTED, 이상이고 임계 미만이면 UNCLEAR
 * @param maxPhotos          게시물 한 건의 최대 사진 장수
 * @param voteExp            투표 한 번의 EXP
 * @param dailyVoteExpGrants EXP를 주는 하루 투표 횟수 상한
 */
public record ProofSettings(
        int minVotes,
        double agreeThreshold,
        double unclearFloor,
        int maxPhotos,
        int voteExp,
        int dailyVoteExpGrants) {

    public ProofSettings {
        if (minVotes < 1) {
            throw new IllegalArgumentException("app.proof.min-votes must be at least 1");
        }
        if (unclearFloor > agreeThreshold) {
            throw new IllegalArgumentException(
                    "app.proof.unclear-floor must not exceed app.proof.agree-threshold");
        }
        if (maxPhotos < 1) {
            throw new IllegalArgumentException("app.proof.max-photos must be at least 1");
        }
    }
}
