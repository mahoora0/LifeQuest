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
    ACCESSORY_LOCKED(HttpStatus.FORBIDDEN, "ACCESSORY_LOCKED", "아직 해금되지 않은 액세서리입니다."),
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
    QUEST_FEATURE_LOCKED(HttpStatus.FORBIDDEN, "QUEST_FEATURE_LOCKED", "아직 열리지 않은 퀘스트 기능입니다."),
    GROUP_NOT_FOUND(HttpStatus.NOT_FOUND, "GROUP_NOT_FOUND", "그룹을 찾을 수 없습니다."),
    GROUP_ACCESS_DENIED(HttpStatus.FORBIDDEN, "GROUP_ACCESS_DENIED", "그룹 접근 권한이 없습니다."),
    GROUP_OWNER_REQUIRED(HttpStatus.FORBIDDEN, "GROUP_OWNER_REQUIRED", "그룹장 권한이 필요합니다."),
    GROUP_ARCHIVED(HttpStatus.CONFLICT, "GROUP_ARCHIVED", "보관된 그룹에서는 변경할 수 없습니다."),
    GROUP_FULL(HttpStatus.CONFLICT, "GROUP_FULL", "그룹 정원이 가득 찼습니다."),
    GROUP_MEMBERSHIP_ALREADY_EXISTS(HttpStatus.CONFLICT, "GROUP_MEMBERSHIP_ALREADY_EXISTS", "이미 가입, 초대 또는 승인 대기 중입니다."),
    GROUP_INVITATION_NOT_FOUND(HttpStatus.NOT_FOUND, "GROUP_INVITATION_NOT_FOUND", "유효한 그룹 초대를 찾을 수 없습니다."),
    GROUP_INVITATION_EXPIRED(HttpStatus.CONFLICT, "GROUP_INVITATION_EXPIRED", "그룹 초대가 만료되었습니다."),
    GROUP_JOIN_REQUEST_NOT_FOUND(HttpStatus.NOT_FOUND, "GROUP_JOIN_REQUEST_NOT_FOUND", "가입 요청을 찾을 수 없습니다."),
    CANNOT_INVITE_SELF(HttpStatus.BAD_REQUEST, "CANNOT_INVITE_SELF", "자기 자신을 초대할 수 없습니다."),
    OWNER_CANNOT_LEAVE(HttpStatus.CONFLICT, "OWNER_CANNOT_LEAVE", "그룹장은 권한 위임 후 탈퇴할 수 있습니다."),
    INVALID_OWNER_TRANSFER(HttpStatus.CONFLICT, "INVALID_OWNER_TRANSFER", "그룹장 권한을 위임할 수 없는 대상입니다."),
    GROUP_QUEST_ALREADY_STARTED(HttpStatus.CONFLICT, "GROUP_QUEST_ALREADY_STARTED", "이미 시작된 그룹 퀘스트입니다."),
    GROUP_QUEST_CANCELLED(HttpStatus.CONFLICT, "GROUP_QUEST_CANCELLED", "취소된 그룹 퀘스트입니다."),
    GROUP_QUEST_ALREADY_COMPLETED(HttpStatus.CONFLICT, "GROUP_QUEST_ALREADY_COMPLETED", "이미 완료된 그룹 퀘스트입니다."),
    GROUP_QUEST_NOT_STARTED(HttpStatus.CONFLICT, "GROUP_QUEST_NOT_STARTED", "시작 시각 이후에 공동 완료할 수 있습니다."),
    GROUP_QUEST_PARTICIPATION_CLOSED(HttpStatus.CONFLICT, "GROUP_QUEST_PARTICIPATION_CLOSED", "그룹 퀘스트 참여 신청이 마감되었습니다."),
    GROUP_QUEST_NOT_PARTICIPATING(HttpStatus.CONFLICT, "GROUP_QUEST_NOT_PARTICIPATING", "참여 중인 그룹 퀘스트가 아닙니다."),
    GROUP_QUEST_NO_PARTICIPANTS(HttpStatus.CONFLICT, "GROUP_QUEST_NO_PARTICIPANTS", "완료할 참여자가 없습니다."),
    GROUP_QUEST_FULL(HttpStatus.CONFLICT, "GROUP_QUEST_FULL", "그룹 퀘스트 정원이 찼습니다."),
    GROUP_QUEST_CAPACITY_BELOW_APPLIED(HttpStatus.CONFLICT, "GROUP_QUEST_CAPACITY_BELOW_APPLIED", "이미 신청한 인원보다 적게 정원을 줄일 수 없습니다."),
    LLM_NOT_CONFIGURED(HttpStatus.SERVICE_UNAVAILABLE, "LLM_NOT_CONFIGURED", "퀘스트 추천 서비스가 설정되지 않았습니다."),
    LLM_DAILY_LIMIT_EXCEEDED(HttpStatus.TOO_MANY_REQUESTS, "LLM_DAILY_LIMIT_EXCEEDED", "오늘의 추천 요청 한도를 모두 사용했습니다."),
    LLM_PROVIDER_RATE_LIMITED(HttpStatus.BAD_GATEWAY, "LLM_PROVIDER_RATE_LIMITED", "추천 제공자가 일시적으로 요청을 제한했습니다."),
    LLM_PROVIDER_TIMEOUT(HttpStatus.GATEWAY_TIMEOUT, "LLM_PROVIDER_TIMEOUT", "추천 생성 시간이 초과되었습니다."),
    LLM_PROVIDER_ERROR(HttpStatus.BAD_GATEWAY, "LLM_PROVIDER_ERROR", "추천 제공자 응답을 처리하지 못했습니다."),
    LLM_INVALID_RESPONSE(HttpStatus.BAD_GATEWAY, "LLM_INVALID_RESPONSE", "추천 결과 형식이 올바르지 않습니다."),
    WEEKLY_AI_QUEST_ALREADY_CLAIMED(
            HttpStatus.CONFLICT,
            "WEEKLY_AI_QUEST_ALREADY_CLAIMED",
            "이번 주 AI 퀘스트는 이미 받았습니다."),
    // "이미 받았다"와 구분한다 — 이쪽은 아직 안 받았는데 자리가 없는 경우다(슬롯 규칙이
    // 바뀌기 전에 만들어진 주기의 자동 배정 3개가 남아 있는 동안 생긴다).
    WEEKLY_AI_SLOT_UNAVAILABLE(
            HttpStatus.CONFLICT,
            "WEEKLY_AI_SLOT_UNAVAILABLE",
            "이번 주는 주간 퀘스트 자리가 이미 찼어요. 다음 주에 받을 수 있어요."),
    RECOMMENDATION_CANDIDATE_NOT_FOUND(
            HttpStatus.NOT_FOUND,
            "RECOMMENDATION_CANDIDATE_NOT_FOUND",
            "추천 후보를 찾을 수 없습니다."),
    RECOMMENDATION_CANDIDATE_ALREADY_CLAIMED(
            HttpStatus.CONFLICT,
            "RECOMMENDATION_CANDIDATE_ALREADY_CLAIMED",
            "이미 퀘스트로 받은 추천입니다."),
    // 후보가 만들어진 주가 지났다는 뜻이다. NOT_FOUND로 뭉뚱그리면 화면에 후보가 보이는 채로
    // "찾을 수 없습니다"가 떠서 버그로 읽힌다 — 다시 추천받으면 된다는 것을 알려야 한다.
    RECOMMENDATION_CANDIDATE_EXPIRED(
            HttpStatus.CONFLICT,
            "RECOMMENDATION_CANDIDATE_EXPIRED",
            "새로운 주가 시작됐어요. 추천을 다시 받아 주세요."),
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
    INVALID_PROOF_IMAGE(
            HttpStatus.BAD_REQUEST,
            "INVALID_PROOF_IMAGE",
            "5MB 이하의 JPG, PNG 또는 WebP 이미지를 선택해 주세요."),
    PROOF_IMAGE_UPLOAD_FAILED(
            HttpStatus.INTERNAL_SERVER_ERROR,
            "PROOF_IMAGE_UPLOAD_FAILED",
            "인증 사진을 저장하지 못했습니다."),
    PROOF_PHOTO_REQUIRED(
            HttpStatus.BAD_REQUEST,
            "PROOF_PHOTO_REQUIRED",
            "인증 사진을 최소 한 장 첨부해 주세요."),
    PROOF_PHOTO_LIMIT_EXCEEDED(
            HttpStatus.BAD_REQUEST,
            "PROOF_PHOTO_LIMIT_EXCEEDED",
            "인증 사진은 최대 5장까지 올릴 수 있습니다."),
    PROOF_POST_NOT_FOUND(HttpStatus.NOT_FOUND, "PROOF_POST_NOT_FOUND", "인증 게시물을 찾을 수 없습니다."),
    /** 삭제된 게시물의 완료 기록도 포함한다 — 완료 기록은 한 번 쓰면 다시 쓸 수 없다(V14). */
    PROOF_ALREADY_POSTED(
            HttpStatus.CONFLICT,
            "PROOF_ALREADY_POSTED",
            "이 퀘스트 완료 기록은 이미 인증에 사용했습니다."),
    PROOF_CONTENT_TOO_LONG(
            HttpStatus.BAD_REQUEST,
            "PROOF_CONTENT_TOO_LONG",
            "설명은 500자까지 쓸 수 있습니다."),
    CANNOT_VOTE_OWN_PROOF(
            HttpStatus.BAD_REQUEST,
            "CANNOT_VOTE_OWN_PROOF",
            "자신의 인증 게시물에는 투표할 수 없습니다."),
    PROOF_ALREADY_VOTED(HttpStatus.CONFLICT, "PROOF_ALREADY_VOTED", "이미 투표한 게시물입니다."),
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
