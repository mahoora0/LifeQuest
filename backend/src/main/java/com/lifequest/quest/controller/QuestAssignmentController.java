package com.lifequest.quest.controller;

import com.lifequest.common.response.ApiResponse;
import com.lifequest.quest.dto.DailyQuestResponse;
import com.lifequest.quest.dto.QuestSummaryResponse;
import com.lifequest.quest.dto.TodayQuestsResponse;
import com.lifequest.quest.service.QuestAssignmentService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * 퀘스트 배정·조회 엔드포인트. 계약은 {@code docs/04-api-spec.md} §3.
 *
 * <p>완료는 {@link QuestCompletionController}가 다룬다 — 그쪽 경로 변수는 퀘스트 원본이 아니라
 * <b>배정</b> ID이고, 앱은 여기서 받은 {@code dailyQuestId}로 그 API를 부른다.
 *
 * <p><b>{@code /nearby}를 {@code /{questId}}보다 먼저 선언한다.</b> Spring은 리터럴 경로를
 * 패턴보다 우선하므로 순서가 동작을 바꾸지는 않지만, 뒤에 두면 읽는 사람이 매번 그 사실을
 * 확인해야 한다. 앱 라우터도 같은 이유로 순서를 지키고 있다({@code app_router.dart}).
 */
@RestController
@RequestMapping("/api/quests")
public class QuestAssignmentController {

    private final QuestAssignmentService questAssignmentService;

    public QuestAssignmentController(QuestAssignmentService questAssignmentService) {
        this.questAssignmentService = questAssignmentService;
    }

    /**
     * 오늘의 퀘스트 목록. 배정이 없으면 이 호출이 만든다(지연 생성).
     *
     * <p>조회인데 쓰기가 일어나는 것은 의도된 설계다 — 배치로 미리 만들면 접속하지 않은
     * 사용자의 행까지 매일 생긴다(docs/05-business-rules.md §1).
     */
    @GetMapping("/today")
    public ResponseEntity<ApiResponse<TodayQuestsResponse>> today(@AuthenticationPrincipal Jwt jwt) {
        return ResponseEntity.ok(ApiResponse.success(
            questAssignmentService.getTodayQuests(Long.valueOf(jwt.getSubject()))));
    }

    /**
     * 오늘 배정된 위치 퀘스트 중 주변 항목. 거리 오름차순이다.
     *
     * @param radiusKm 지도에서 볼 범위. 퀘스트별 인증 반경과는 다른 값이다
     */
    @GetMapping("/nearby")
    public ResponseEntity<ApiResponse<Map<String, List<DailyQuestResponse>>>> nearby(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam Double lat,
            @RequestParam Double lng,
            @RequestParam(defaultValue = "5") Double radiusKm) {

        List<DailyQuestResponse> quests = questAssignmentService.getNearbyQuests(
            Long.valueOf(jwt.getSubject()), lat, lng, radiusKm);

        return ResponseEntity.ok(ApiResponse.success(Map.of("quests", quests)));
    }

    /** 퀘스트 원본 상세. 배정 여부와 무관하며 비활성 퀘스트도 돌려준다. */
    @GetMapping("/{questId}")
    public ResponseEntity<ApiResponse<QuestSummaryResponse>> detail(@PathVariable Long questId) {
        return ResponseEntity.ok(ApiResponse.success(questAssignmentService.getQuest(questId)));
    }
}