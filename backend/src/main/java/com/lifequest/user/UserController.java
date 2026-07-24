package com.lifequest.user;

import com.lifequest.common.response.ApiResponse;
import com.lifequest.user.dto.UpdateProfileRequest;
import com.lifequest.user.dto.UserProfileResponse;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.security.core.annotation.AuthenticationPrincipal;

@RestController
@RequestMapping("/api/users/me")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping
    public ApiResponse<UserProfileResponse> me(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(userService.getProfile(userId(jwt)));
    }

    @PatchMapping
    public ApiResponse<UserProfileResponse> update(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody UpdateProfileRequest request) {
        return ApiResponse.success(userService.updateProfile(userId(jwt), request));
    }

    @GetMapping("/level")
    public ApiResponse<Map<String, Integer>> level(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(userService.getLevel(userId(jwt)));
    }

    @GetMapping("/titles")
    public ApiResponse<Map<String, Object>> titles(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(Map.of("titles", List.of()));
    }

    @GetMapping("/rewards")
    public ApiResponse<Map<String, Object>> rewards(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.success(Map.of("titles", List.of(), "profileItems", List.of()));
    }

    @GetMapping("/quests/history")
    public ApiResponse<Map<String, Object>> questHistory(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.success(Map.of(
                "content", List.of(),
                "page", page,
                "size", size,
                "totalElements", 0));
    }

    private Long userId(Jwt jwt) {
        return Long.valueOf(jwt.getSubject());
    }
}
