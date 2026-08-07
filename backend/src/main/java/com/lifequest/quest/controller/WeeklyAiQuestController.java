package com.lifequest.quest.controller;

import com.lifequest.common.response.ApiResponse;
import com.lifequest.quest.dto.ClaimWeeklyAiQuestRequest;
import com.lifequest.quest.dto.DailyQuestResponse;
import com.lifequest.quest.service.WeeklyAiQuestService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 주간 AI 슬롯 선택 엔드포인트.
 *
 * <p>본문에 후보 <b>id만</b> 받는다. 내용을 받으면 제목·완료 가이드를 앱에서 바꿔 보낼 수 있어
 * {@code QuestRecommendationValidator}가 예산·기간을 검증한 의미가 사라진다.
 *
 * <p>경로를 {@code /api/quests} 아래 두는 이유는 결과가 배정이기 때문이다 — 응답은 목록
 * 항목과 같은 모양이고, 완료는 기존 {@code /api/daily-quests/{id}/complete}를 그대로 탄다.
 */
@RestController
@RequestMapping("/api/quests/weekly/ai")
public class WeeklyAiQuestController {

    private final WeeklyAiQuestService weeklyAiQuestService;

    public WeeklyAiQuestController(WeeklyAiQuestService weeklyAiQuestService) {
        this.weeklyAiQuestService = weeklyAiQuestService;
    }

    @PostMapping
    public ResponseEntity<ApiResponse<DailyQuestResponse>> claim(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody ClaimWeeklyAiQuestRequest request) {
        return ResponseEntity.ok(ApiResponse.success(
            weeklyAiQuestService.claim(Long.valueOf(jwt.getSubject()), request.candidateId())));
    }
}
