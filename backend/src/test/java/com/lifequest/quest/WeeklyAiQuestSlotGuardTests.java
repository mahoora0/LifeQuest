package com.lifequest.quest;

import com.jayway.jsonpath.JsonPath;
import com.lifequest.common.exception.BusinessException;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.domain.UserDailyQuest;
import com.lifequest.quest.repository.QuestRepository;
import com.lifequest.quest.repository.UserDailyQuestRepository;
import com.lifequest.quest.service.QuestPeriod;
import com.lifequest.recommendation.DurationUnit;
import com.lifequest.recommendation.LlmProvider;
import com.lifequest.recommendation.QuestRecommendationCandidate;
import com.lifequest.recommendation.RecommendationCategory;
import com.lifequest.recommendation.RecommendationType;
import com.lifequest.recommendation.RoutingQuestRecommendationProvider;
import com.lifequest.recommendation.WeeklyRecommendationCandidateRepository;
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 주간 AI 슬롯의 <b>사전 검사</b>와 동시성.
 *
 * <p>추천 생성과 선택이 같은 판정({@code WeeklyAiQuestSlot})을 쓰는지, 그리고 그 판정이
 * 사용량 차감보다 앞에 있는지를 고정한다. 판정이 한쪽에만 있으면 다른 쪽으로 우회된다 —
 * 추천 쪽에 없으면 이미 받은 사용자가 LLM 비용을 계속 쓰고, 선택 쪽에 없으면 API를 직접
 * 부르는 경로가 남는다.
 */
@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
class WeeklyAiQuestSlotGuardTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private QuestRepository questRepository;

    @Autowired
    private UserDailyQuestRepository userDailyQuestRepository;

    @Autowired
    private WeeklyRecommendationCandidateRepository candidateRepository;

    @Autowired
    private QuestPeriod questPeriod;

    @Autowired
    private com.lifequest.quest.service.WeeklyAiQuestService weeklyAiQuestService;

    @MockitoBean
    private RoutingQuestRecommendationProvider provider;

    @BeforeEach
    void stubProvider() {
        reset(provider);
        when(provider.selected()).thenReturn(LlmProvider.OPENAI);
        when(provider.model()).thenReturn("gpt-test");
        when(provider.generate(any(), anyString(), anyString()))
            .thenAnswer(invocation -> candidates(invocation.getArgument(0)));
    }

    /**
     * 이미 받은 사용자는 추천 생성 자체가 막힌다.
     *
     * <p>막지 않으면 LLM을 호출해 하루 횟수와 API 비용을 쓰고, 마지막 선택에서야 409를 만난다.
     * 사용량이 그대로인 것으로 차감 전에 막혔음을 확인한다.
     */
    @Test
    void 이번_주에_이미_받았으면_추천_생성부터_막는다() throws Exception {
        String token = weeklyUser("guard-claimed");

        MvcResult first = weeklyPlace(token).andExpect(status().isOk()).andReturn();
        int remainingBefore = JsonPath.read(
            first.getResponse().getContentAsString(), "$.data.remainingRequestsToday");
        long candidateId = firstCandidateId(first);
        mockMvc.perform(claim(token, candidateId)).andExpect(status().isOk());

        reset(provider);
        weeklyPlace(token)
            .andExpect(status().isConflict())
            .andExpect(jsonPath("$.error.code").value("WEEKLY_AI_QUEST_ALREADY_CLAIMED"));

        // LLM을 부르지 않았다
        verifyNoInteractions(provider);
        assertThat(remainingBefore).as("첫 주간 추천이 1회 차감").isEqualTo(9);

        // 사용량도 줄지 않았는지 확인한다. 일반 추천을 한 번 써서 잔여를 읽으면,
        // 막힌 주간 추천이 차감됐다면 7이고 차감되지 않았다면 8이다.
        stubProvider();
        MvcResult probe = mockMvc.perform(post("/api/quest-recommendations/place")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(placeRequest()))
            .andExpect(status().isOk())
            .andReturn();
        int remainingAfter = JsonPath.read(
            probe.getResponse().getContentAsString(), "$.data.remainingRequestsToday");
        assertThat(remainingAfter).as("막힌 주간 추천은 사용량을 쓰지 않는다").isEqualTo(8);
    }

    /**
     * 주간 배정이 이미 3개면 자리가 없다 — "이미 받았다"와 다른 코드를 준다.
     *
     * <p>슬롯 규칙이 바뀌기 전에 만들어진 주기의 자동 배정 3개가 남아 있는 동안 생긴다.
     * 앱이 카드를 감추는 것만으로는 API를 직접 부르는 경로가 남으므로 <b>서버가 지켜야 한다</b>.
     */
    @Test
    void 주간_배정이_이미_세_개면_자리가_없다고_거부한다() throws Exception {
        String email = email("guard-full");
        String token = weeklyUser(email, "자리없음");
        Long userId = userId(email);

        // 구 규칙으로 만들어진 상태를 재현한다 — 자동 주간 3개
        fillWeeklyAssignments(userId, 3);

        weeklyPlace(token)
            .andExpect(status().isConflict())
            .andExpect(jsonPath("$.error.code").value("WEEKLY_AI_SLOT_UNAVAILABLE"));
        verifyNoInteractions(provider);
    }

    /** 자동 2개인 정상 상태에서는 그대로 받을 수 있다 — 상한이 정상 경로를 막으면 안 된다. */
    @Test
    void 주간_배정이_두_개면_그대로_받을_수_있다() throws Exception {
        String email = email("guard-open");
        String token = weeklyUser(email, "자리있음");
        fillWeeklyAssignments(userId(email), 2);

        MvcResult result = weeklyPlace(token).andExpect(status().isOk()).andReturn();
        mockMvc.perform(claim(token, firstCandidateId(result))).andExpect(status().isOk());
    }

    /** 상태 API는 진입 전에 슬롯 가부와 남은 일수를 알려준다. */
    @Test
    void 상태_API가_슬롯_가부와_남은_일수를_알려준다() throws Exception {
        String token = weeklyUser("guard-status");

        mockMvc.perform(get("/api/quest-recommendations/weekly/status")
                .header("Authorization", "Bearer " + token))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.available").value(true))
            .andExpect(jsonPath("$.data.reason").doesNotExist())
            .andExpect(jsonPath("$.data.remainingDays").isNumber());

        MvcResult result = weeklyPlace(token).andExpect(status().isOk()).andReturn();
        mockMvc.perform(claim(token, firstCandidateId(result))).andExpect(status().isOk());

        mockMvc.perform(get("/api/quest-recommendations/weekly/status")
                .header("Authorization", "Bearer " + token))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.available").value(false))
            .andExpect(jsonPath("$.data.reason").value("WEEKLY_AI_QUEST_ALREADY_CLAIMED"));
    }

    /**
     * 같은 사용자가 <b>서로 다른 두 후보</b>를 동시에 고른다.
     *
     * <p>주당 1회 보장의 핵심이다. {@code uk_weekly_ai_claim_period}가 없다면 두 요청이 모두
     * "받은 적 없음"을 보고 각각 퀘스트를 만들어 그 주 AI 퀘스트가 둘이 된다. 후보가 다르므로
     * {@code uk_weekly_ai_claim_candidate}는 이 경우를 막지 못한다 — 두 제약의 책임이 다르다는
     * 것을 이 테스트가 고정한다.
     */
    @Test
    void 서로_다른_후보를_동시에_골라도_하나만_통과한다() throws Exception {
        String email = email("guard-race");
        String token = weeklyUser(email, "경합");
        Long userId = userId(email);

        MvcResult result = weeklyPlace(token).andExpect(status().isOk()).andReturn();
        List<Integer> ids = JsonPath.read(
            result.getResponse().getContentAsString(), "$.data.candidates[*].candidateId");

        // 서비스를 직접 부른다. MockMvc는 스레드 간 공유를 전제하지 않아 동시성 테스트에
        // 쓰면 결과가 아니라 프레임워크를 재는 셈이 된다(기존 동시성 테스트도 같은 방식이다).
        //
        // 시작점은 각 태스크가 스스로 내리는 래치로 맞춘다. 바깥에서 countDown 하려 들면
        // invokeAll이 완료를 기다리는 사이 태스크는 그 신호를 기다려 서로 막힌다.
        CountDownLatch ready = new CountDownLatch(2);
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            List<Future<Boolean>> futures = pool.invokeAll(List.of(
                claimTask(userId, ids.get(0).longValue(), ready),
                claimTask(userId, ids.get(1).longValue(), ready)));

            int ok = 0;
            for (Future<Boolean> future : futures) {
                if (future.get(20, TimeUnit.SECONDS)) {
                    ok++;
                }
            }
            assertThat(ok).as("동시 선택 중 정확히 하나만 성공해야 한다").isEqualTo(1);
        } finally {
            pool.shutdownNow();
        }

        // 응답만 맞고 행이 둘이면 의미가 없다 — 실제로 남은 AI 퀘스트도 하나뿐이어야 한다
        assertThat(questRepository.findAll().stream()
            .filter(quest -> userId.equals(quest.getOwnerUserId()))
            .count())
            .as("그 주의 개인 AI 퀘스트는 하나여야 한다")
            .isEqualTo(1);
    }

    /**
     * 보관 기간이 지난 <b>미선택</b> 후보는 다음 추천 때 정리된다.
     *
     * <p>스케줄러를 두지 않고 지연 정리로 맞춘다(V19의 "배치 스케줄러를 두지 않는다"와 같은 결).
     * 선택된 후보는 claim이 FK로 참조하므로 남아야 한다.
     */
    @Test
    void 오래된_미선택_후보는_다음_추천에서_정리된다() throws Exception {
        String email = email("guard-purge");
        String token = weeklyUser(email, "정리");
        Long userId = userId(email);
        LocalDate periodStart = questPeriod.create(QuestCadence.WEEKLY).getStartAt();

        var stale = candidateRepository.save(new com.lifequest.recommendation.WeeklyRecommendationCandidate(
            userId, periodStart.minusWeeks(8), candidate(1, RecommendationType.PLACE, DurationUnit.MINUTES, 120),
            java.time.LocalDateTime.now()));
        var recent = candidateRepository.save(new com.lifequest.recommendation.WeeklyRecommendationCandidate(
            userId, periodStart.minusWeeks(1), candidate(2, RecommendationType.PLACE, DurationUnit.MINUTES, 120),
            java.time.LocalDateTime.now()));

        weeklyPlace(token).andExpect(status().isOk());

        assertThat(candidateRepository.findById(stale.getId()))
            .as("보관 기간(4주)을 넘긴 미선택 후보는 지워진다").isEmpty();
        assertThat(candidateRepository.findById(recent.getId()))
            .as("보관 기간 안의 후보는 남는다").isPresent();
    }

    // ---------------------------------------------------------------- 헬퍼

    /** 성공하면 true. 제약에 걸린 쪽은 BusinessException을 받고 false를 돌려준다. */
    private Callable<Boolean> claimTask(Long userId, long candidateId, CountDownLatch ready) {
        return () -> {
            ready.countDown();
            ready.await(5, TimeUnit.SECONDS);
            try {
                weeklyAiQuestService.claim(userId, candidateId);
                return true;
            } catch (BusinessException expected) {
                return false;
            }
        };
    }

    private void fillWeeklyAssignments(Long userId, int count) {
        LocalDate periodStart = questPeriod.create(QuestCadence.WEEKLY).getStartAt();
        var expiresAt = questPeriod.create(QuestCadence.WEEKLY).getExpiresAt();
        List<Quest> weekly = questRepository.findByActiveTrueAndOwnerUserIdIsNull().stream()
            .filter(quest -> quest.getCadence() == QuestCadence.WEEKLY)
            .limit(count)
            .toList();
        if (weekly.size() < count) {
            throw new IllegalStateException("주간 시드가 모자란다: " + weekly.size());
        }
        for (Quest quest : weekly) {
            userDailyQuestRepository.save(
                new UserDailyQuest(userId, quest.getId(), periodStart, expiresAt));
        }
    }

    private org.springframework.test.web.servlet.ResultActions weeklyPlace(String token)
            throws Exception {
        return mockMvc.perform(post("/api/quest-recommendations/weekly/place")
            .header("Authorization", "Bearer " + token)
            .contentType(MediaType.APPLICATION_JSON)
            .content(placeRequest()));
    }

    private org.springframework.test.web.servlet.RequestBuilder claim(String token, long candidateId) {
        return post("/api/quests/weekly/ai")
            .header("Authorization", "Bearer " + token)
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"candidateId\": %d}".formatted(candidateId));
    }

    private long firstCandidateId(MvcResult result) throws Exception {
        List<Integer> ids = JsonPath.read(
            result.getResponse().getContentAsString(), "$.data.candidates[*].candidateId");
        return ids.get(0).longValue();
    }

    private String placeRequest() {
        return """
            {"area":"서울 성수동","availableMinutes":180,"budgetPerPerson":30000,
             "companionCount":2,"environment":"ANY","interests":["산책"]}
            """;
    }

    private List<QuestRecommendationCandidate> candidates(RecommendationType type) {
        DurationUnit unit = type == RecommendationType.PLACE ? DurationUnit.MINUTES : DurationUnit.DAYS;
        int duration = type == RecommendationType.PLACE ? 120 : 1;
        return List.of(
            candidate(1, type, unit, duration),
            candidate(2, type, unit, duration),
            candidate(3, type, unit, duration));
    }

    private QuestRecommendationCandidate candidate(int index, RecommendationType type,
                                                   DurationUnit unit, int duration) {
        return new QuestRecommendationCandidate(
            index, null, type, "추천 " + index, "충분히 구체적인 추천 설명입니다 " + index,
            RecommendationCategory.CULTURE, duration, unit, 10000,
            "추천 장소 " + index, "현장에서 경험을 완료하고 기록하세요 " + index);
    }

    private String weeklyUser(String prefix) throws Exception {
        return weeklyUser(email(prefix), prefix);
    }

    private String weeklyUser(String email, String nicknamePrefix) throws Exception {
        String token = signUpAndGetAccessToken(email, nickname(nicknamePrefix));
        User user = userRepository.findByEmailIgnoreCase(email).orElseThrow();
        user.addExp(0, 3);
        userRepository.saveAndFlush(user);
        return token;
    }

    private String email(String prefix) {
        return prefix + "-" + UUID.randomUUID().toString().substring(0, 8) + "@lifequest.test";
    }

    private String nickname(String prefix) {
        return prefix.replaceAll("[^가-힣a-zA-Z0-9_]", "")
            + UUID.randomUUID().toString().replace("-", "").substring(0, 6);
    }

    private Long userId(String email) {
        return userRepository.findByEmailIgnoreCase(email).orElseThrow().getId();
    }

    private String signUpAndGetAccessToken(String email, String nickname) throws Exception {
        mockMvc.perform(post("/api/auth/signup")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"email": "%s", "password": "password123", "nickname": "%s"}
                    """.formatted(email, nickname)))
            .andExpect(status().isCreated());

        MvcResult login = mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"email": "%s", "password": "password123"}
                    """.formatted(email)))
            .andExpect(status().isOk())
            .andReturn();
        return JsonPath.read(login.getResponse().getContentAsString(), "$.data.accessToken");
    }
}
