package com.lifequest.collection;

import com.lifequest.common.response.ApiResponse;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
class AchievementController {

    private final AchievementService achievementService;

    AchievementController(AchievementService achievementService) {
        this.achievementService = achievementService;
    }

    @GetMapping("/achievements")
    ApiResponse<AchievementResponse> catalog(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(achievementService.catalog(Long.valueOf(jwt.getSubject())));
    }

    @GetMapping("/users/me/achievements")
    ApiResponse<AchievementResponse> mine(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(achievementService.mine(Long.valueOf(jwt.getSubject())));
    }
}
