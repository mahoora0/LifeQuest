package com.lifequest.social;

import com.lifequest.common.response.ApiResponse;
import com.lifequest.social.dto.DeleteFriendResponse;
import com.lifequest.social.dto.FriendPageResponse;
import com.lifequest.social.dto.FriendProfileResponse;
import com.lifequest.social.dto.FriendRequestPageResponse;
import com.lifequest.social.dto.RespondFriendRequestRequest;
import com.lifequest.social.dto.RespondFriendRequestResponse;
import com.lifequest.social.dto.SendFriendRequestRequest;
import com.lifequest.social.dto.SendFriendRequestResponse;
import com.lifequest.social.dto.SentFriendRequestPageResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
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

    @GetMapping("/requests/sent")
    public ApiResponse<SentFriendRequestPageResponse> sentRequests(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.success(friendService.getSentRequests(userId(jwt), page, size));
    }

    // 친구 목록 조회
    @GetMapping
    public ApiResponse<FriendPageResponse> friends(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.success(friendService.getFriends(userId(jwt), page, size));
    }

    // 친구 관계 삭제
    @DeleteMapping("/{friendId}")
    public ApiResponse<DeleteFriendResponse> deleteFriend(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long friendId) {
        return ApiResponse.success(friendService.deleteFriend(userId(jwt), friendId));
    }

    // 친구 공개 프로필과 활동 요약 조회
    @GetMapping("/{friendId}/profile")
    public ApiResponse<FriendProfileResponse> friendProfile(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long friendId) {
        return ApiResponse.success(friendService.getFriendProfile(userId(jwt), friendId));
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
