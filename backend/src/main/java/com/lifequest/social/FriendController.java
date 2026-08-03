package com.lifequest.social;

import com.lifequest.common.response.ApiResponse;
import com.lifequest.social.dto.FriendRequestPageResponse;
import com.lifequest.social.dto.RespondFriendRequestRequest;
import com.lifequest.social.dto.RespondFriendRequestResponse;
import com.lifequest.social.dto.SendFriendRequestRequest;
import com.lifequest.social.dto.SendFriendRequestResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/friends")
public class FriendController {

    private final FriendService friendService;

    public FriendController(FriendService friendService) {
        this.friendService = friendService;
    }

    // 친구 요청 전송
    @PostMapping("/requests")
    public ResponseEntity<ApiResponse<SendFriendRequestResponse>> sendRequest(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody SendFriendRequestRequest request) {
        SendFriendRequestResponse response = friendService.sendRequest(
                userId(jwt),
                request.receiverId());
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(response));
    }

    // 받은 친구 요청 목록 조회
    @GetMapping("/requests")
    public ApiResponse<FriendRequestPageResponse> receivedRequests(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.success(
                friendService.getReceivedRequests(userId(jwt), page, size));
    }

    // 친구 요청 수락 또는 거절
    @PatchMapping("/requests/{requestId}")
    public ApiResponse<RespondFriendRequestResponse> respondToRequest(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long requestId,
            @Valid @RequestBody RespondFriendRequestRequest request) {
        return ApiResponse.success(
                friendService.respondToRequest(
                        userId(jwt),
                        requestId,
                        request.action()));
    }

    // 사용자 ID를 JWT에서 추출
    private Long userId(Jwt jwt) {
        return Long.valueOf(jwt.getSubject());
    }
}
