package com.lifequest.common.exception;

public class BusinessException extends RuntimeException {

    private final ErrorCode errorCode;

    public BusinessException(ErrorCode errorCode) {
        super(errorCode.message());
        this.errorCode = errorCode;
    }

    /**
     * 상황에 따라 달라지는 값을 안내에 실어야 할 때 쓴다.
     *
     * <p>퀘스트 완료의 {@code OUT_OF_RADIUS}가 그렇다 — 계약이 "반경 밖"뿐 아니라
     * <b>현재 거리</b>까지 요구한다({@code docs/04-api-spec.md} §4). 앱도 이 코드에서는
     * 서버 메시지가 있으면 그것을 그대로 보여주고, 없을 때만 기본 문구로 되돌아간다.
     * 고정 메시지만 쓸 수 있으면 "조금 더 가까이 가 주세요"까지가 한계다.
     *
     * @param errorCode 응답에 실릴 코드와 HTTP 상태
     * @param message   {@code errorCode.message()} 대신 내보낼 안내. 상황값을 담는다
     */
    public BusinessException(ErrorCode errorCode, String message) {
        super(message);
        this.errorCode = errorCode;
    }

    public ErrorCode errorCode() {
        return errorCode;
    }
}
