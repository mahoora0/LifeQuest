package com.lifequest.recommendation;
import com.lifequest.common.response.ApiResponse;import com.lifequest.recommendation.dto.*;import jakarta.validation.Valid;import org.springframework.security.core.annotation.AuthenticationPrincipal;import org.springframework.security.oauth2.jwt.Jwt;import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/quest-recommendations")
public class QuestRecommendationController {
 private final QuestRecommendationService service;public QuestRecommendationController(QuestRecommendationService service){this.service=service;}
 @PostMapping("/place") public ApiResponse<QuestRecommendationResponse> place(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody PlaceQuestRecommendationRequest r){return ApiResponse.success(service.place(uid(jwt),r));}
 @PostMapping("/travel") public ApiResponse<QuestRecommendationResponse> travel(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody TravelQuestRecommendationRequest r){return ApiResponse.success(service.travel(uid(jwt),r));}
 private Long uid(Jwt jwt){return Long.valueOf(jwt.getSubject());}
}
