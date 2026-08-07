package com.lifequest.quest;

import com.jayway.jsonpath.JsonPath;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.repository.QuestRepository;
import com.lifequest.recommendation.DurationUnit;
import com.lifequest.recommendation.LlmProvider;
import com.lifequest.recommendation.QuestRecommendationCandidate;
import com.lifequest.recommendation.RecommendationCategory;
import com.lifequest.recommendation.RecommendationType;
import com.lifequest.recommendation.RoutingQuestRecommendationProvider;
import com.lifequest.recommendation.WeeklyRecommendationCandidate;
import com.lifequest.recommendation.WeeklyRecommendationCandidateRepository;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.service.QuestPeriod;
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 주간 AI 슬롯의 전체 흐름 — 추천 → 후보 저장 → 선택 → 배정.
 *
 * <p><b>{@code @Transactional}을 붙이지 않는다.</b> 배정 생성이 {@code REQUIRES_NEW}라 테스트
 * 트랜잭션이 롤백돼도 커밋된다({@code QuestAssignmentContractTests}와 같은 이유). 대신 테스트마다
 * 다른 이메일을 써서 사용자별로 상태를 가른다.
 *
 * <p>LLM은 {@link RoutingQuestRecommendationProvider}를 대역으로 바꿔 고정 후보를 돌려준다.
 * 실제 호출은 네트워크·키·비용이 필요하고 응답이 매번 달라 계약을 고정할 수 없다.
 */
@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
class WeeklyAiQuestFlowIntegrationTests {

    /** 주간에서 자동으로 채우는 슬롯 수. 세 번째는 이 테스트가 다루는 AI 슬롯이다. */
    private static final int WEEKLY_AUTO_SLOTS = 2;

    private static final int DAILY_SLOTS = 3;

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private QuestRepository questRepository;

    @Autowired
    private WeeklyRecommendationCandidateRepository candidateRepository;

    @Autowired
    private QuestPeriod questPeriod;

    @Autowired
    private JdbcTemplate jdbcTemplate;

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

    // ---------------------------------------------------------------- 추천·저장

    /**
     * 주간 추천만 후보를 저장한다. 저장하지 않으면 "이 후보를 받겠다"는 요청이 후보 내용을
     * 되돌려 보내야 하고, 그러면 제목·완료 가이드를 앱에서 바꿔 보낼 수 있다.
     */
    @Test
    void 주간_추천은_후보를_저장하고_candidateId를_함께_내려준다() throws Exception {
        String token = weeklyUnlockedUser("weekly-store");

        MvcResult result = requestWeeklyPlace(token)
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.candidates.length()").value(3))
            .andReturn();

        List<Integer> ids = JsonPath.read(
            result.getResponse().getContentAsString(), "$.data.candidates[*].candidateId");
        assertThat(ids).hasSize(3).doesNotContainNull();

        // index는 저장 순서와 같아야 한다 — 앱이 "1. …"로 표시하는 번호이고 선택은 id로 하므로,
        // 둘이 어긋나면 사용자가 고른 것과 다른 퀘스트가 들어간다
        List<Integer> indexes = JsonPath.read(
            result.getResponse().getContentAsString(), "$.data.candidates[*].index");
        assertThat(indexes).containsExactly(1, 2, 3);
    }

    /** 일반 추천은 저장하지 않는다 — 구경만 하는 요청까지 쌓으면 후보 테이블이 채워진다. */
    @Test
    void 일반_추천은_후보를_저장하지_않아_candidateId가_비어_있다() throws Exception {
        String token = weeklyUnlockedUser("general-nostore");
        long before = candidateRepository.count();

        mockMvc.perform(post("/api/quest-recommendations/place")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(placeRequest()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.candidates[0].candidateId").doesNotExist());

        assertThat(candidateRepository.count()).isEqualTo(before);
    }

    /**
     * Lv.3 검사가 사용량 차감보다 먼저다. 뒤에 있으면 받을 수도 없는 추천 때문에 하루 10회 중
     * 1회를 잃는다 — 여기서는 승급 후 첫 요청의 잔여가 9인 것으로 확인한다(8이면 이미 태운 것이다).
     */
    @Test
    void 잠긴_사용자는_주간_추천에서_사용량을_잃지_않는다() throws Exception {
        String email = email("weekly-locked");
        String token = signUpAndGetAccessToken(email, nickname("잠금"));

        requestWeeklyPlace(token)
            .andExpect(status().isForbidden())
            .andExpect(jsonPath("$.error.code").value("QUEST_FEATURE_LOCKED"));
        verifyNoInteractions(provider);

        levelUp(email, 3);
        requestWeeklyPlace(token)
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.remainingRequestsToday").value(9));
    }

    // ---------------------------------------------------------------- 선택

    /** 고른 후보가 주간 세 번째 자리에 들어간다. 등급·EXP·완료 방식은 서버가 고정한다. */
    @Test
    void 고른_후보가_주간_세_번째_퀘스트가_된다() throws Exception {
        String email = email("weekly-claim");
        String token = weeklyUnlockedUser(email, "선택");

        long candidateId = firstCandidateId(token);

        mockMvc.perform(claim(token, candidateId))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.dailyQuestId").isNumber())
            .andExpect(jsonPath("$.data.status").value("ASSIGNED"))
            .andExpect(jsonPath("$.data.quest.cadence").value("WEEKLY"))
            .andExpect(jsonPath("$.data.quest.completionType").value("SELF_REPORT"))
            .andExpect(jsonPath("$.data.quest.createdBy").value("AI"))
            .andExpect(jsonPath("$.data.quest.grade").value("RARE"))
            .andExpect(jsonPath("$.data.quest.expReward").value(40))
            .andExpect(jsonPath("$.data.quest.completionGuide").isNotEmpty())
            // 좌표를 만들지 않는다 — 만들면 GPS 판정 대상이 되는데 검증할 근거가 없다
            .andExpect(jsonPath("$.data.quest.latitude").doesNotExist())
            .andExpect(jsonPath("$.data.quest.radiusM").doesNotExist());

        MvcResult today = getToday(token);
        List<String> cadences = JsonPath.read(
            today.getResponse().getContentAsString(), "$.data.quests[*].quest.cadence");
        assertThat(cadences).filteredOn("WEEKLY"::equals).hasSize(WEEKLY_AUTO_SLOTS + 1);
        assertThat(cadences).filteredOn("DAILY"::equals).hasSize(DAILY_SLOTS);
    }

    /**
     * <b>순서를 뒤집어도 주간이 3개가 되어야 한다.</b>
     *
     * <p>AI 퀘스트도 cadence가 WEEKLY라, 자동 생성 판정이 "이 트랙에 배정이 하나라도 있나"로
     * 남아 있으면 AI를 먼저 받은 사용자의 자동 2개가 영영 생기지 않는다. 자동을 먼저 받는
     * 순서로는 통과하므로 이 방향으로만 잡힌다.
     */
    @Test
    void AI_퀘스트를_먼저_받아도_자동_주간_두_개가_그대로_생성된다() throws Exception {
        String email = email("weekly-order");
        String token = signUpAndGetAccessToken(email, nickname("순서"));
        levelUp(email, 3);

        // 오늘의 퀘스트를 한 번도 부르지 않은 상태에서 추천 → 선택으로 곧장 간다
        long candidateId = firstCandidateId(token);
        mockMvc.perform(claim(token, candidateId)).andExpect(status().isOk());

        MvcResult today = getToday(token);
        List<String> cadences = JsonPath.read(
            today.getResponse().getContentAsString(), "$.data.quests[*].quest.cadence");
        assertThat(cadences)
            .as("AI를 먼저 받아도 자동 주간 2개가 채워져야 한다")
            .filteredOn("WEEKLY"::equals).hasSize(WEEKLY_AUTO_SLOTS + 1);

        List<String> creators = JsonPath.read(
            today.getResponse().getContentAsString(),
            "$.data.quests[?(@.quest.cadence == 'WEEKLY')].quest.createdBy");
        assertThat(creators).filteredOn("AI"::equals).hasSize(1);
    }

    /** 주당 1회. 두 번째 선택은 409이며, 판정은 {@code uk_weekly_ai_claim_period}가 한다. */
    @Test
    void 같은_주에_두_번째_선택은_거부된다() throws Exception {
        String token = weeklyUnlockedUser("weekly-twice");

        MvcResult first = requestWeeklyPlace(token).andExpect(status().isOk()).andReturn();
        List<Integer> ids = JsonPath.read(
            first.getResponse().getContentAsString(), "$.data.candidates[*].candidateId");

        mockMvc.perform(claim(token, ids.get(0))).andExpect(status().isOk());

        // 다른 후보를 골라도 막힌다 — 제약은 후보가 아니라 주(user_id, period_start)를 본다
        mockMvc.perform(claim(token, ids.get(1)))
            .andExpect(status().isConflict())
            .andExpect(jsonPath("$.error.code").value("WEEKLY_AI_QUEST_ALREADY_CLAIMED"));
    }

    /** 남의 후보 id를 찍어봐도 존재 여부가 새면 안 된다 — 403이 아니라 404다. */
    @Test
    void 다른_사용자의_후보는_선택할_수_없다() throws Exception {
        String ownerToken = weeklyUnlockedUser("weekly-owner");
        String otherToken = weeklyUnlockedUser("weekly-other");

        long ownerCandidateId = firstCandidateId(ownerToken);

        mockMvc.perform(claim(otherToken, ownerCandidateId))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.error.code").value("RECOMMENDATION_CANDIDATE_NOT_FOUND"));
    }

    /**
     * 주기가 넘어간 후보는 NOT_FOUND가 아니라 EXPIRED다. 화면에 후보가 보이는 채로
     * "찾을 수 없습니다"가 뜨면 버그로 읽힌다.
     */
    @Test
    void 지난_주의_후보는_만료로_구분해_거부한다() throws Exception {
        String email = email("weekly-stale");
        String token = weeklyUnlockedUser(email, "만료");
        Long userId = userId(email);

        WeeklyRecommendationCandidate stale = candidateRepository.save(
            new WeeklyRecommendationCandidate(
                userId,
                questPeriod.create(QuestCadence.WEEKLY).getStartAt().minusDays(7),
                candidate(1, RecommendationType.PLACE, DurationUnit.MINUTES, 120),
                LocalDateTime.now()));

        mockMvc.perform(claim(token, stale.getId()))
            .andExpect(status().isConflict())
            .andExpect(jsonPath("$.error.code").value("RECOMMENDATION_CANDIDATE_EXPIRED"));
    }

    @Test
    void 없는_후보를_고르면_404다() throws Exception {
        String token = weeklyUnlockedUser("weekly-missing");

        mockMvc.perform(claim(token, 999_999L))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.error.code").value("RECOMMENDATION_CANDIDATE_NOT_FOUND"));
    }

    @Test
    void 잠긴_사용자는_후보를_선택할_수_없다() throws Exception {
        String email = email("weekly-claim-locked");
        String token = weeklyUnlockedUser(email, "선택잠금");
        long candidateId = firstCandidateId(token);

        levelDown(email);

        mockMvc.perform(claim(token, candidateId))
            .andExpect(status().isForbidden())
            .andExpect(jsonPath("$.error.code").value("QUEST_FEATURE_LOCKED"));
    }

    // ---------------------------------------------------------------- 격리

    /**
     * 개인 AI 퀘스트는 다른 사용자의 배정 풀에 들어가지 않는다.
     *
     * <p>풀 조회에서 {@code owner_user_id IS NULL}이 빠지면 남이 만든 개인 퀘스트가 배정된다.
     * 배정은 확률 추출이라 그런 행이 섞여도 예외가 나지 않아 결과로는 드러나지 않는다.
     */
    @Test
    void 개인_AI_퀘스트는_다른_사용자에게_배정되지_않는다() throws Exception {
        String ownerEmail = email("weekly-pool-owner");
        String ownerToken = weeklyUnlockedUser(ownerEmail, "풀주인");
        mockMvc.perform(claim(ownerToken, firstCandidateId(ownerToken))).andExpect(status().isOk());

        Long ownerId = userId(ownerEmail);
        Quest aiQuest = questRepository.findAll().stream()
            .filter(quest -> ownerId.equals(quest.getOwnerUserId()))
            .findFirst()
            .orElseThrow();

        assertThat(questRepository.findByActiveTrueAndOwnerUserIdIsNull())
            .as("개인 퀘스트는 배정 풀 조회에 나오면 안 된다")
            .noneMatch(quest -> quest.getId().equals(aiQuest.getId()));

        String otherEmail = email("weekly-pool-other");
        String otherToken = signUpAndGetAccessToken(otherEmail, nickname("풀타인"));
        levelUp(otherEmail, 3);

        List<Integer> otherQuestIds = JsonPath.read(
            getToday(otherToken).getResponse().getContentAsString(), "$.data.quests[*].questId");
        assertThat(otherQuestIds).doesNotContain(aiQuest.getId().intValue());
    }

    /** 개인 AI 퀘스트 상세는 주인만 볼 수 있다. 존재 여부가 새지 않도록 403이 아니라 404다. */
    @Test
    void 개인_AI_퀘스트_상세는_주인만_조회할_수_있다() throws Exception {
        String ownerEmail = email("weekly-detail-owner");
        String ownerToken = weeklyUnlockedUser(ownerEmail, "상세주인");
        mockMvc.perform(claim(ownerToken, firstCandidateId(ownerToken))).andExpect(status().isOk());

        Long ownerId = userId(ownerEmail);
        Quest aiQuest = questRepository.findAll().stream()
            .filter(quest -> ownerId.equals(quest.getOwnerUserId()))
            .findFirst()
            .orElseThrow();

        mockMvc.perform(get("/api/quests/{id}", aiQuest.getId())
                .header("Authorization", "Bearer " + ownerToken))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.createdBy").value("AI"));

        String otherToken = signUpAndGetAccessToken(email("weekly-detail-other"), nickname("상세타인"));
        mockMvc.perform(get("/api/quests/{id}", aiQuest.getId())
                .header("Authorization", "Bearer " + otherToken))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.error.code").value("RESOURCE_NOT_FOUND"));
    }

    /**
     * 어드민 카탈로그는 개인 AI 퀘스트를 다루지 않는다.
     *
     * <p>목록만 막으면 부족하다 — 수정·비활성화는 id만 알면 되는 경로라 어드민이 특정 사용자의
     * 개인 퀘스트를 바꾸거나 내려버릴 수 있다.
     */
    @Test
    void 어드민_카탈로그는_개인_AI_퀘스트를_다루지_않는다() throws Exception {
        String ownerEmail = email("weekly-admin-owner");
        String ownerToken = weeklyUnlockedUser(ownerEmail, "어드민대상");
        mockMvc.perform(claim(ownerToken, firstCandidateId(ownerToken))).andExpect(status().isOk());

        Long ownerId = userId(ownerEmail);
        Quest aiQuest = questRepository.findAll().stream()
            .filter(quest -> ownerId.equals(quest.getOwnerUserId()))
            .findFirst()
            .orElseThrow();

        String adminEmail = email("weekly-admin");
        String adminToken = signUpAndGetAccessToken(adminEmail, nickname("관리자"));
        jdbcTemplate.update("UPDATE users SET role = 'ADMIN' WHERE email = ?", adminEmail);
        adminToken = login(adminEmail);

        // 목록은 createdAt DESC라 막지 않으면 1페이지가 개인 퀘스트로 덮인다
        MvcResult list = mockMvc.perform(get("/api/admin/quests")
                .header("Authorization", "Bearer " + adminToken)
                .param("page", "0").param("size", "50"))
            .andExpect(status().isOk())
            .andReturn();
        List<Integer> listedIds = JsonPath.read(
            list.getResponse().getContentAsString(), "$.data.content[*].id");
        assertThat(listedIds).doesNotContain(aiQuest.getId().intValue());

        mockMvc.perform(patch("/api/admin/quests/{id}", aiQuest.getId())
                .header("Authorization", "Bearer " + adminToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"title":"관리자가 바꾼 제목"}
                    """))
            .andExpect(status().isNotFound());

        mockMvc.perform(delete("/api/admin/quests/{id}", aiQuest.getId())
                .header("Authorization", "Bearer " + adminToken))
            .andExpect(status().isNotFound());
    }

    // ---------------------------------------------------------------- 헬퍼

    private org.springframework.test.web.servlet.ResultActions requestWeeklyPlace(String token)
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

    private long firstCandidateId(String token) throws Exception {
        MvcResult result = requestWeeklyPlace(token).andExpect(status().isOk()).andReturn();
        List<Integer> ids = JsonPath.read(
            result.getResponse().getContentAsString(), "$.data.candidates[*].candidateId");
        return ids.get(0).longValue();
    }

    private MvcResult getToday(String token) throws Exception {
        return mockMvc.perform(get("/api/quests/today").header("Authorization", "Bearer " + token))
            .andExpect(status().isOk())
            .andReturn();
    }

    private String weeklyUnlockedUser(String prefix) throws Exception {
        return weeklyUnlockedUser(email(prefix), prefix);
    }

    private String weeklyUnlockedUser(String email, String nicknamePrefix) throws Exception {
        String token = signUpAndGetAccessToken(email, nickname(nicknamePrefix));
        levelUp(email, 3);
        return token;
    }

    private String email(String prefix) {
        return prefix + "-" + UUID.randomUUID().toString().substring(0, 8) + "@lifequest.test";
    }

    /** 닉네임은 한글·영문·숫자·밑줄만 허용한다({@code SignupRequest}) — 접두사의 하이픈을 턴다. */
    private String nickname(String prefix) {
        return prefix.replaceAll("[^가-힣a-zA-Z0-9_]", "")
            + UUID.randomUUID().toString().replace("-", "").substring(0, 6);
    }

    private Long userId(String email) {
        return userRepository.findByEmailIgnoreCase(email).orElseThrow().getId();
    }

    private void levelUp(String email, int level) {
        User user = userRepository.findByEmailIgnoreCase(email).orElseThrow();
        user.addExp(0, level);
        userRepository.saveAndFlush(user);
    }

    private void levelDown(String email) {
        jdbcTemplate.update("UPDATE users SET level = 1 WHERE email = ?", email);
    }

    private String placeRequest() {
        return """
            {"area":"서울 성수동","availableMinutes":180,"budgetPerPerson":30000,
             "companionCount":2,"environment":"ANY","interests":["산책","전시"],
             "additionalRequest":"조용한 활동"}
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

    private String signUpAndGetAccessToken(String email, String nickname) throws Exception {
        mockMvc.perform(post("/api/auth/signup")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"email": "%s", "password": "password123", "nickname": "%s"}
                    """.formatted(email, nickname)))
            .andExpect(status().isCreated());
        return login(email);
    }

    private String login(String email) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"email": "%s", "password": "password123"}
                    """.formatted(email)))
            .andExpect(status().isOk())
            .andReturn();
        return JsonPath.read(result.getResponse().getContentAsString(), "$.data.accessToken");
    }
}
