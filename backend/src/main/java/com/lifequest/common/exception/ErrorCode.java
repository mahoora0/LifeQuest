package com.lifequest.common.exception;

import org.springframework.http.HttpStatus;

public enum ErrorCode {
    INVALID_REQUEST(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "요청 형식이 올바르지 않습니다."),
    VALIDATION_FAILED(HttpStatus.BAD_REQUEST, "VALIDATION_FAILED", "입력값을 확인해 주세요."),
    UNAUTHORIZED(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "인증이 필요합니다."),
    INVALID_CREDENTIALS(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "이메일 또는 비밀번호가 올바르지 않습니다."),
    TOKEN_EXPIRED(HttpStatus.UNAUTHORIZED, "TOKEN_EXPIRED", "인증이 만료되었습니다. 다시 로그인해 주세요."),
    INVALID_GOOGLE_TOKEN(HttpStatus.UNAUTHORIZED, "INVALID_GOOGLE_TOKEN", "Google 인증 정보를 확인할 수 없습니다."),
    AUTH_PROVIDER_NOT_CONFIGURED(
            HttpStatus.SERVICE_UNAVAILABLE,
            "AUTH_PROVIDER_NOT_CONFIGURED",
            "Google 로그인이 아직 설정되지 않았습니다."),
    FORBIDDEN(HttpStatus.FORBIDDEN, "FORBIDDEN", "접근 권한이 없습니다."),
    CHARACTER_LOCKED(HttpStatus.FORBIDDEN, "CHARACTER_LOCKED", "아직 해금되지 않은 캐릭터입니다."),
    DUPLICATE_EMAIL(HttpStatus.CONFLICT, "DUPLICATE_EMAIL", "이미 가입된 이메일입니다."),
    DUPLICATE_NICKNAME(HttpStatus.CONFLICT, "DUPLICATE_NICKNAME", "이미 사용 중인 닉네임입니다."),
    INVALID_PROFILE_IMAGE(
            HttpStatus.BAD_REQUEST,
            "INVALID_PROFILE_IMAGE",
            "5MB 이하의 JPG, PNG 또는 WebP 이미지를 선택해 주세요."),
    PROFILE_IMAGE_UPLOAD_FAILED(
            HttpStatus.INTERNAL_SERVER_ERROR,
            "PROFILE_IMAGE_UPLOAD_FAILED",
            "프로필 이미지를 저장하지 못했습니다."),
    RESOURCE_NOT_FOUND(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "대상을 찾을 수 없습니다."),
    /**
     * 매핑된 컨트롤러가 없는 경로. {@link #RESOURCE_NOT_FOUND}와 구분한다 —
     * 그쪽은 엔드포인트가 살아 있고 대상만 없는 경우라 재시도가 의미를 가질 수 있지만,
     * 이쪽은 아직 만들지 않은 기능이라 다시 요청해도 결과가 같다.
     * 클라이언트는 이 코드를 보고 오류 화면 대신 "준비 중" 안내를 띄운다.
     */
    ENDPOINT_NOT_FOUND(HttpStatus.NOT_FOUND, "ENDPOINT_NOT_FOUND", "아직 제공되지 않는 기능입니다."),
    QUEST_EXPIRED(HttpStatus.CONFLICT, "QUEST_EXPIRED", "만료된 퀘스트는 완료할 수 없습니다."),
    OUT_OF_RADIUS(HttpStatus.UNPROCESSABLE_CONTENT, "OUT_OF_RADIUS", "퀘스트 인증 반경 밖입니다."),
    LOCATION_REQUIRED(HttpStatus.BAD_REQUEST, "LOCATION_REQUIRED", "위치 좌표 또는 정확도가 필요합니다."),
    LOCATION_ACCURACY_TOO_LOW(
            HttpStatus.UNPROCESSABLE_CONTENT,
            "LOCATION_ACCURACY_TOO_LOW",
            "위치 정확도가 허용 기준보다 낮습니다."),
    DUPLICATE_FRIEND_REQUEST(
            HttpStatus.CONFLICT,
            "DUPLICATE_FRIEND_REQUEST",
            "이미 대기 중인 친구 요청이 있거나 친구 관계입니다."),
    SELF_FRIEND_REQUEST_NOT_ALLOWED(
            HttpStatus.BAD_REQUEST,
            "SELF_FRIEND_REQUEST_NOT_ALLOWED",
            "자기 자신에게 친구 요청을 보낼 수 없습니다."),
    FRIENDSHIP_NOT_FOUND(
            HttpStatus.NOT_FOUND,
            "FRIENDSHIP_NOT_FOUND",
            "친구 관계를 찾을 수 없습니다."),
    CONFLICT(HttpStatus.CONFLICT, "CONFLICT", "현재 상태에서는 요청을 처리할 수 없습니다."),
    INTERNAL_SERVER_ERROR(
            HttpStatus.INTERNAL_SERVER_ERROR,
            "INTERNAL_SERVER_ERROR",
            "서버 오류가 발생했습니다.");

    private final HttpStatus status;
    private final String code;
    private final String message;

    ErrorCode(HttpStatus status, String code, String message) {
        this.status = status;
        this.code = code;
        this.message = message;
    }

    public HttpStatus status() {
        return status;
    }

    public String code() {
        return code;
    }

    public String message() {
        return message;
    }
}
