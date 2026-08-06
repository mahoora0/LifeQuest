package com.lifequest.quest;

import com.jayway.jsonpath.JsonPath;
import com.lifequest.quest.domain.QuestAssignmentMarker;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.repository.QuestAssignmentMarkerRepository;
import com.lifequest.quest.repository.UserDailyQuestRepository;
import com.lifequest.quest.service.QuestPeriod;
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 배정 API가 계약대로 응답하는지 고정한다. 계약 원본은 {@code docs/04-api-spec.md} §3,
 * 배정 규칙은 {@code docs/05-business-rules.md} §1.
 *
 * <p>설계 정본(볼트 {@code 2026-08-05-quest-assignment-core-design})의 테스트 표 중
 * <b>9(잠금)·10(멱등)</b>을 여기서 닫는다. 11(경합)·12(재조회)는 H2로 재현되지 않아
 * MySQL 실측이 필요하며 이 파일 밖이다.
 *
 * <p><b>{@code @Transactional}을 붙이지 않는다.</b> 생성 트랜잭션이 {@code REQUIRES_NEW}라
 * 테스트 트랜잭션이 롤백돼도 배정은 커밋된다 — 롤백에 기대면 오염이 조용히 남는다.
 * 대신 테스트마다 다른 이메일을 써서 사용자별로 상태를 가른다.
 *
 * <p>배정 내용은 확률 추출이라 매번 다르다. 그래서 <b>어떤 퀘스트가 뽑혔는지가 아니라
 * 개수·구조·트랙</b>만 단언한다. 분포 자체는 순수 계층에서 이미 검증했다
 * ({@code QuestSlotDrawerTests}).
 */
@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
class QuestAssignmentContractTests {

    /** 트랙당 슬롯 수(docs/05-business-rules.md §1-A). */
    private static final int SLOTS_PER_TRACK = 3;

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserDailyQuestRepository userDailyQuestRepository;

    @Autowired
    private QuestAssignmentMarkerRepository markerRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private QuestPeriod questPeriod;

    /**
     * 항목 9 — 잠금. 신규 사용자는 Lv.1이라 주간이 잠겨 있고(요구 Lv.3), 일간만 배정된다.
     * <b>주간 마커도 생기지 않아야 한다</b> — 마커만 남으면 승급 후에도 배정이 채워지지 않는다.
     */
    @Test
    void 잠긴_트랙은_배정도_마커도_생기지_않는다() throws Exception {
        String email = "assign-lock@lifequest.test";
        String token = signUpAndGetAccessToken(email, "잠금탐험가");
        Long userId = userId(email);

        MvcResult result = mockMvc.perform(get("/api/quests/today").header("Authorization", "Bearer " + token))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.quests.length()").value(SLOTS_PER_TRACK))
            .andReturn();

        List<String> cadences = JsonPath.read(
            result.getResponse().getContentAsString(), "$.data.quests[*].quest.cadence");
        assertThat(cadences).containsOnly(QuestCadence.DAILY.name());

        assertThat(markerRepository.findAll().stream()
            .filter(marker -> marker.getUserId().equals(userId))
            .map(marker -> marker.getCadence()))
            .as("주간은 잠겼으므로 마커가 생기면 안 된다 — 남으면 승급 후에도 배정이 채워지지 않는다")
            .containsExactly(QuestCadence.DAILY);
    }

    /**
     * 항목 10 — 멱등. 지연 생성이라 조회가 곧 생성 시도이므로, 두 번 부르면 6개가 되는지가
     * 실제 위험이다. 마커가 그것을 막는다.
     */
    @Test
    void 같은_주기에_두_번_조회해도_배정이_늘지_않는다() throws Exception {
        String email = "assign-idempotent@lifequest.test";
        String token = signUpAndGetAccessToken(email, "멱등탐험가");
        Long userId = userId(email);

        List<Integer> first = questIdsOf(getToday(token));
        List<Integer> second = questIdsOf(getToday(token));

        assertThat(second).isEqualTo(first);
        assertThat(userDailyQuestRepository.findByUserIdAndAssignedDate(
            userId, questPeriod.logicalDate()))
            .hasSize(SLOTS_PER_TRACK);
    }

    /**
     * 경합에서 밀린 요청이 500이 아니라 정상 응답을 받는다.
     *
     * <p>마커만 미리 넣어 <b>다른 요청이 이미 이겼다</b>는 상태를 만든다. 실제 경합에서는
     * 이긴 쪽이 배정까지 만들지만, 여기서 재는 것은 배정 내용이 아니라 <b>밀린 쪽이
     * 응답을 만들어내는가</b>이다.
     *
     * <p>이 경로는 MySQL 실측(동시 요청 5개)에서 500으로 드러났다. 생성 트랜잭션이
     * {@code REQUIRES_NEW}인데 유니크 위반을 그 안에서 잡고 {@code return}하면, flush가
     * 실패한 세션을 Spring이 커밋하려 들어 요청이 죽는다. 예외가 밖으로 나가 트랜잭션이
     * 롤백으로 끝나야 호출자가 이어갈 수 있다.
     *
     * <p><b>순차 호출로는 이 자리를 지나지 않는다</b> — 두 번째 호출은 배정이 이미 있어
     * 생성을 부르지 않기 때문이다. 마커를 직접 넣는 것이 단위 테스트로 재현하는 방법이다.
     */
    @Test
    void 마커가_이미_있으면_생성을_건너뛰고_정상_응답한다() throws Exception {
        String email = "assign-lost-race@lifequest.test";
        String token = signUpAndGetAccessToken(email, "경합탐험가");
        Long userId = userId(email);

        markerRepository.saveAndFlush(new QuestAssignmentMarker(
            userId, QuestCadence.DAILY, questPeriod.logicalDate(), LocalDateTime.now()));

        mockMvc.perform(get("/api/quests/today").header("Authorization", "Bearer " + token))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.assignedDate").value(questPeriod.logicalDate().toString()));
    }

    /** 주간이 열린 사용자는 두 트랙을 각각 3개씩 받는다 — 트랙별 독립 슬롯(§1-A). */
    @Test
    void 주간이_열리면_트랙마다_세_개씩_배정된다() throws Exception {
        String email = "assign-weekly@lifequest.test";
        String token = signUpAndGetAccessToken(email, "주간탐험가");
        levelUp(email, 3);

        MvcResult result = mockMvc.perform(get("/api/quests/today").header("Authorization", "Bearer " + token))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.quests.length()").value(SLOTS_PER_TRACK * 2))
            .andReturn();

        List<String> cadences = JsonPath.read(
            result.getResponse().getContentAsString(), "$.data.quests[*].quest.cadence");
        assertThat(cadences).filteredOn(QuestCadence.DAILY.name()::equals).hasSize(SLOTS_PER_TRACK);
        assertThat(cadences).filteredOn(QuestCadence.WEEKLY.name()::equals).hasSize(SLOTS_PER_TRACK);
    }

    /**
     * 응답 계약. 앱은 {@code dailyQuestId}로 완료 API를 부르므로 이 필드가 비면 완료 경로가
     * 통째로 막힌다. {@code assignedDate}는 조회 시점의 논리적 일자다.
     */
    @Test
    void 응답이_계약대로_배정_식별자와_퀘스트_요약을_함께_싣는다() throws Exception {
        String token = signUpAndGetAccessToken("assign-contract@lifequest.test", "계약탐험가");

        mockMvc.perform(get("/api/quests/today").header("Authorization", "Bearer " + token))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.assignedDate").value(questPeriod.logicalDate().toString()))
            .andExpect(jsonPath("$.data.quests[0].dailyQuestId").isNumber())
            .andExpect(jsonPath("$.data.quests[0].questId").isNumber())
            .andExpect(jsonPath("$.data.quests[0].status").value("ASSIGNED"))
            .andExpect(jsonPath("$.data.quests[0].quest.title").isNotEmpty())
            .andExpect(jsonPath("$.data.quests[0].quest.expReward").isNumber())
            .andExpect(jsonPath("$.data.quests[0].quest.completionType").isNotEmpty())
            // 목록에는 거리를 채울 근거가 없다 — 0을 넣으면 앱이 "바로 앞"으로 읽는다
            .andExpect(jsonPath("$.data.quests[0].distanceM").doesNotExist());
    }

    @Test
    void 인증_없이_오늘의_퀘스트를_조회할_수_없다() throws Exception {
        mockMvc.perform(get("/api/quests/today")).andExpect(status().isUnauthorized());
    }

    @Test
    void 퀘스트_상세는_배정과_무관하게_조회된다() throws Exception {
        String token = signUpAndGetAccessToken("assign-detail@lifequest.test", "상세탐험가");

        mockMvc.perform(get("/api/quests/1").header("Authorization", "Bearer " + token))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.questId").value(1))
            .andExpect(jsonPath("$.data.title").isNotEmpty());
    }

    @Test
    void 없는_퀘스트_상세는_404다() throws Exception {
        String token = signUpAndGetAccessToken("assign-missing@lifequest.test", "부재탐험가");

        mockMvc.perform(get("/api/quests/999999").header("Authorization", "Bearer " + token))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.error.code").value("RESOURCE_NOT_FOUND"));
    }

    /**
     * 반경 밖은 빠진다. 좌표를 위경도 범위 밖이 아니라 <b>실제로 먼 지점</b>으로 두어,
     * 필터가 도는지와 검증이 도는지를 섞지 않는다.
     */
    @Test
    void 주변_퀘스트는_반경으로_걸러지고_거리가_실린다() throws Exception {
        String token = signUpAndGetAccessToken("assign-nearby@lifequest.test", "주변탐험가");

        // 시드 좌표는 전부 대한민국이다. 반경을 지구 규모로 두면 배정된 LOCATION이 전부 들어온다
        MvcResult wide = mockMvc.perform(get("/api/quests/nearby")
                .param("lat", "37.5665").param("lng", "126.9780").param("radiusKm", "20000")
                .header("Authorization", "Bearer " + token))
            .andExpect(status().isOk())
            .andReturn();

        List<Double> distances = JsonPath.read(
            wide.getResponse().getContentAsString(), "$.data.quests[*].distanceM");
        assertThat(distances).isSorted();

        // 같은 좌표에 1m 반경이면 정확히 그 지점에 있는 퀘스트만 남는다 — 시드에는 없다
        mockMvc.perform(get("/api/quests/nearby")
                .param("lat", "37.5665").param("lng", "126.9780").param("radiusKm", "0.001")
                .header("Authorization", "Bearer " + token))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.quests.length()").value(0));
    }

    @Test
    void 위경도_범위를_벗어나면_검증_실패다() throws Exception {
        String token = signUpAndGetAccessToken("assign-badcoord@lifequest.test", "좌표탐험가");

        mockMvc.perform(get("/api/quests/nearby")
                .param("lat", "91").param("lng", "126.9780").param("radiusKm", "5")
                .header("Authorization", "Bearer " + token))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.error.code").value("VALIDATION_FAILED"));
    }

    @Test
    void 반경이_0이하면_검증_실패다() throws Exception {
        String token = signUpAndGetAccessToken("assign-badradius@lifequest.test", "반경탐험가");

        mockMvc.perform(get("/api/quests/nearby")
                .param("lat", "37.5665").param("lng", "126.9780").param("radiusKm", "0")
                .header("Authorization", "Bearer " + token))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.error.code").value("VALIDATION_FAILED"));
    }

    private MvcResult getToday(String token) throws Exception {
        return mockMvc.perform(get("/api/quests/today").header("Authorization", "Bearer " + token))
            .andExpect(status().isOk())
            .andReturn();
    }

    private List<Integer> questIdsOf(MvcResult result) throws Exception {
        return JsonPath.read(result.getResponse().getContentAsString(), "$.data.quests[*].questId");
    }

    private Long userId(String email) {
        return userRepository.findByEmailIgnoreCase(email).orElseThrow().getId();
    }

    private void levelUp(String email, int level) {
        User user = userRepository.findByEmailIgnoreCase(email).orElseThrow();
        user.addExp(0, level);
        userRepository.saveAndFlush(user);
    }

    private String signUpAndGetAccessToken(String email, String nickname) throws Exception {
        mockMvc.perform(post("/api/auth/signup")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                      "email": "%s",
                      "password": "password123",
                      "nickname": "%s"
                    }
                    """.formatted(email, nickname)))
            .andExpect(status().isCreated());

        MvcResult login = mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                      "email": "%s",
                      "password": "password123"
                    }
                    """.formatted(email)))
            .andExpect(status().isOk())
            .andReturn();

        return JsonPath.read(login.getResponse().getContentAsString(), "$.data.accessToken");
    }
}
