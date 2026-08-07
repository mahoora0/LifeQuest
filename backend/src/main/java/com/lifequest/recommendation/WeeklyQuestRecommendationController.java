package com.lifequest.recommendation;
import com.lifequest.common.response.ApiResponse;import com.lifequest.recommendation.dto.*;import jakarta.validation.Valid;import org.springframework.security.core.annotation.AuthenticationPrincipal;import org.springframework.security.oauth2.jwt.Jwt;import org.springframework.web.bind.annotation.*;

/**
 * 주간 퀘스트용 추천. 일반 추천({@link QuestRecommendationController})과 경로를 나눈 이유는
 * 검증 규칙이 다르기 때문이다 — Lv.3 잠금과 남은 기간 제한이 여기에만 걸린다. 요청 본문에
 * 목적 필드를 넣어 한 경로에서 분기하면 그 차이가 본문 값에 숨는다.
 */
@RestController @RequestMapping("/api/quest-recommendations/weekly")
public class WeeklyQuestRecommendationController {
 private final WeeklyQuestRecommendationService service;public WeeklyQuestRecommendationController(WeeklyQuestRecommendationService service){this.service=service;}
 @PostMapping("/place") public ApiResponse<QuestRecommendationResponse> place(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody PlaceQuestRecommendationRequest r){return ApiResponse.success(service.place(uid(jwt),r));}
 @PostMapping("/travel") public ApiResponse<QuestRecommendationResponse> travel(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody TravelQuestRecommendationRequest r){return ApiResponse.success(service.travel(uid(jwt),r));}
 private Long uid(Jwt jwt){return Long.valueOf(jwt.getSubject());}
}
