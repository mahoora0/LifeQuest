package com.lifequest.collection;

import com.lifequest.common.response.ApiResponse;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
class LifedexController {

    private final LifedexService lifedexService;

    LifedexController(LifedexService lifedexService) {
        this.lifedexService = lifedexService;
    }

    @GetMapping("/lifedex/categories")
    ApiResponse<LifedexCategoryResponse> categories(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(lifedexService.categories(userId(jwt)));
    }

    @GetMapping("/lifedex")
    ApiResponse<LifedexResponse> items(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(required = false) Long categoryId) {
        return ApiResponse.success(lifedexService.items(userId(jwt), categoryId));
    }

    @GetMapping("/users/me/lifedex")
    ApiResponse<LifedexCategoryResponse> mine(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(lifedexService.categories(userId(jwt)));
    }

    private static Long userId(Jwt jwt) {
        return Long.valueOf(jwt.getSubject());
    }
}
