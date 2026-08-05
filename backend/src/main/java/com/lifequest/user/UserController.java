package com.lifequest.user;

import com.lifequest.common.response.ApiResponse;
import com.lifequest.user.dto.UpdateProfileRequest;
import com.lifequest.user.dto.BadgeCollectionResponse;
import com.lifequest.user.dto.CharacterResponse;
import com.lifequest.user.dto.CharacterSelectionRequest;
import com.lifequest.user.dto.AccessoryCollectionResponse;
import com.lifequest.user.dto.AccessorySelectionRequest;
import com.lifequest.user.dto.RepresentativeBadgeRequest;
import com.lifequest.user.dto.RepresentativeTitleRequest;
import com.lifequest.user.dto.RewardHistoryResponse;
import com.lifequest.user.dto.TitleCollectionResponse;
import com.lifequest.user.dto.UserProfileResponse;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.multipart.MultipartFile;

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

    @PostMapping(value = "/profile-image", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ApiResponse<UserProfileResponse> uploadProfileImage(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam("file") MultipartFile file) {
        return ApiResponse.success(userService.uploadProfileImage(userId(jwt), file));
    }

    @DeleteMapping("/profile-image")
    public ApiResponse<UserProfileResponse> deleteProfileImage(
            @AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(userService.deleteProfileImage(userId(jwt)));
    }

    @GetMapping("/level")
    public ApiResponse<Map<String, Object>> level(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(userService.getLevel(userId(jwt)));
    }

    @GetMapping("/characters")
    public ApiResponse<List<CharacterResponse>> characters(
            @AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(userService.getCharacters(userId(jwt)));
    }

    @PatchMapping("/character")
    public ApiResponse<UserProfileResponse> selectCharacter(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody CharacterSelectionRequest request) {
        return ApiResponse.success(
                userService.selectCharacter(userId(jwt), request.characterId()));
    }

    @GetMapping("/accessories")
    public ApiResponse<AccessoryCollectionResponse> accessories(
            @AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(userService.getAccessories(userId(jwt)));
    }

    @PatchMapping("/accessory")
    public ApiResponse<UserProfileResponse> selectAccessory(
            @AuthenticationPrincipal Jwt jwt,
            @RequestBody AccessorySelectionRequest request) {
        return ApiResponse.success(
                userService.selectAccessory(userId(jwt), request.accessoryId()));
    }

    @GetMapping("/titles")
    public ApiResponse<TitleCollectionResponse> titles(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(userService.getTitles(userId(jwt)));
    }

    @PatchMapping("/title")
    public ApiResponse<UserProfileResponse> selectTitle(
            @AuthenticationPrincipal Jwt jwt,
            @RequestBody RepresentativeTitleRequest request) {
        return ApiResponse.success(
                userService.selectRepresentativeTitle(userId(jwt), request.titleId()));
    }

    @GetMapping("/badges")
    public ApiResponse<BadgeCollectionResponse> badges(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(userService.getBadges(userId(jwt)));
    }

    @PatchMapping("/badge")
    public ApiResponse<UserProfileResponse> selectBadge(
            @AuthenticationPrincipal Jwt jwt,
            @RequestBody RepresentativeBadgeRequest request) {
        return ApiResponse.success(
                userService.selectRepresentativeBadge(userId(jwt), request.badgeId()));
    }

    @GetMapping("/rewards")
    public ApiResponse<RewardHistoryResponse> rewards(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.success(userService.getRewards(userId(jwt)));
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
