package com.lifequest.quest.controller;

import com.lifequest.common.response.ApiResponse;
import com.lifequest.quest.dto.QuestCompletionRequest;
import com.lifequest.quest.dto.QuestCompletionResponse;
import com.lifequest.quest.service.QuestCompletionService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

/**
 * 퀘스트 완료 엔드포인트. 계약은 {@code docs/04-api-spec.md} §4.
 *
 * <p>경로 변수는 퀘스트 원본 ID가 아니라 <b>배정</b> ID다. 완료 멱등성이
 * {@code UNIQUE(user_daily_quest_id)} 위에 서 있어서, 배정 건을 지목하지 않으면
 * 무엇이 "한 번"인지 정의할 수 없다.
 */
@RestController
@RequestMapping("/api/daily-quests")
public class QuestCompletionController {

    private final QuestCompletionService questCompletionService;

    public QuestCompletionController(QuestCompletionService questCompletionService) {
        this.questCompletionService = questCompletionService;
    }

    /**
     * 본문을 필수로 두지 않는다. {@code SELF_REPORT} 퀘스트는 좌표 없이 완료하므로
     * 본문 자체를 보내지 않는다({@code docs/04-api-spec.md} §4).
     *
     * <p>좌표가 필요한지 여부는 대상 퀘스트의 {@code completion_type}이 정하므로 판단을
     * 서비스에 맡긴다. 여기서 {@code @Valid}로 막으면 빠진 좌표가 일반 검증 실패가 되어
     * {@code LOCATION_REQUIRED}와 구분되지 않는다.
     */
    @PostMapping("/{dailyQuestId}/complete")
    public ResponseEntity<ApiResponse<QuestCompletionResponse>> complete(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long dailyQuestId,
            @RequestBody(required = false) QuestCompletionRequest request) {

        QuestCompletionResponse response = questCompletionService.complete(
                Long.valueOf(jwt.getSubject()),
                dailyQuestId,
                request != null ? request : new QuestCompletionRequest(null, null, null));

        return ResponseEntity.ok(ApiResponse.success(response));
    }
}
