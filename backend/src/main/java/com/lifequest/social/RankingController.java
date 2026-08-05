package com.lifequest.social;

import com.lifequest.common.response.ApiResponse;
import com.lifequest.social.dto.RankingPageResponse;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/rankings")
public class RankingController {

    private final RankingService rankingService;

    public RankingController(RankingService rankingService) {
        this.rankingService = rankingService;
    }

    @GetMapping("/global")
    public ApiResponse<RankingPageResponse> globalRanking(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "EXP") String type) {
        return ApiResponse.success(
                rankingService.getGlobalRanking(
                        userId(jwt), page, size, RankingType.parse(type)));
    }

    @GetMapping("/friends")
    public ApiResponse<RankingPageResponse> friendRanking(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "EXP") String type) {
        return ApiResponse.success(
                rankingService.getFriendRanking(
                        userId(jwt), page, size, RankingType.parse(type)));
    }

    private Long userId(Jwt jwt) {
        return Long.valueOf(jwt.getSubject());
    }
}
