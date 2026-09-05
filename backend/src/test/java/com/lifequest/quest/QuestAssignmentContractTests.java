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
 * <p>배정 설계가 요구하는 검증 중 <b>잠금·멱등</b>을 여기서 닫는다. <b>경합·재조회</b>는
 * H2로 재현되지 않아(MVCC 구현이 MySQL과 다르다) MySQL 실측이 필요하며 이 파일 밖이다.
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

    /** 주간에서 <b>자동으로</b> 채우는 슬롯 수. 세 번째는 사용자가 AI 추천에서 고른다. */
    private static final int WEEKLY_AUTO_SLOTS = 2;

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

    /**
     * 주간이 열린 사용자는 일간 3개 + 주간 <b>자동 2개</b>를 받는다.
     *
     * <p>주간의 세 번째 자리는 자동으로 채우지 않는다 — 사용자가 AI 추천 중에서 직접 고르는
     * 슬롯이다({@code WeeklyAiQuestService}). 자동으로 3개를 채우면 고를 자리가 없어지고,
     * 네 번째로 얹으면 "트랙당 3개" 계약이 깨진다.
     *
     * <p>빠지는 것은 타입 제한 없는 슬롯 C다. A(LOCATION)는 남는다 — 추천은 좌표를 만들지 못해
     * 항상 SELF_REPORT라 그 자리를 대신할 수 없다.
     */
    @Test
    void 주간은_자동_두_개만_배정되고_세_번째_자리는_비워둔다() throws Exception {
        String email = "assign-weekly@lifequest.test";
        String token = signUpAndGetAccessToken(email, "주간탐험가");
        levelUp(email, 3);

        MvcResult result = mockMvc.perform(get("/api/quests/today").header("Authorization", "Bearer " + token))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.quests.length()").value(SLOTS_PER_TRACK + WEEKLY_AUTO_SLOTS))
            .andReturn();

        String body = result.getResponse().getContentAsString();
        List<String> cadences = JsonPath.read(body, "$.data.quests[*].quest.cadence");
        assertThat(cadences).filteredOn(QuestCadence.DAILY.name()::equals).hasSize(SLOTS_PER_TRACK);
        assertThat(cadences).filteredOn(QuestCadence.WEEKLY.name()::equals).hasSize(WEEKLY_AUTO_SLOTS);

        // 자동 주간 2개는 슬롯 A·B라 완료 타입이 갈린다. 둘 다 SELF_REPORT면 슬롯 C가 아니라
        // A가 빠진 것이고, 그러면 위치 인증 주간 퀘스트가 영영 나오지 않는다.
        List<String> weeklyTypes = JsonPath.read(
            body, "$.data.quests[?(@.quest.cadence == 'WEEKLY')].quest.completionType");
        assertThat(weeklyTypes).containsExactlyInAnyOrder("LOCATION", "SELF_REPORT");
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
     *
     * <p><b>"1m 반경이면 0건"으로 재지 않는다.</b> 배정 풀에 무엇이 들어 있는지는 이 테스트가
     * 정하지 못한다 — 다른 계약 테스트가 만든 SYSTEM 퀘스트 픽스처가 같은 컨텍스트·H2에
     * 커밋된 채 남고, 그중 이 좌표에 있는 것이 추첨되면 0건 단언만 무작위로 깨진다.
     * 필터는 정상인데 테스트가 빨개지는 자리라, <b>개수가 아니라 걸러진 결과 자체</b>를
     * 넓은 반경의 결과와 대조한다. 배정은 주기당 한 번뿐이라 두 조회가 같은 집합을 본다.
     */
    @Test
    void 주변_퀘스트는_반경으로_걸러지고_거리가_실린다() throws Exception {
        String token = signUpAndGetAccessToken("assign-nearby@lifequest.test", "주변탐험가");

        // 시드 좌표는 전부 대한민국이다. 반경을 지구 규모로 두면 배정된 LOCATION이 전부 들어온다
        List<Number> wide = nearbyDistances(token, 20000);
        assertThat(wide).isSorted();

        // 같은 좌표에 1m 반경. 남는 것은 넓은 조회 결과 중 1m 이하인 것뿐이어야 한다
        double narrowRadiusKm = 0.001;
        double narrowRadiusM = narrowRadiusKm * 1000;
        List<Number> narrow = nearbyDistances(token, narrowRadiusKm);

        assertThat(narrow)
            .as("반경 밖이 실려 오면 지도가 닿을 수 없는 퀘스트를 그린다")
            .allSatisfy(distance -> assertThat(distance.doubleValue()).isLessThanOrEqualTo(narrowRadiusM));
        assertThat(narrow)
            .as("반경 안인데 빠지면 필터가 과하게 잘라낸 것이다")
            .containsExactlyElementsOf(
                wide.stream().filter(distance -> distance.doubleValue() <= narrowRadiusM).toList());
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

    /**
     * 서울시청 좌표에서 {@code radiusKm}로 주변 조회를 하고 거리 목록만 꺼낸다. 첫 호출이
     * 배정까지 만드는 진입점이라, 같은 토큰으로 두 번 부르면 두 번째는 같은 집합을 다시 거른다.
     */
    private List<Number> nearbyDistances(String token, double radiusKm) throws Exception {
        MvcResult result = mockMvc.perform(get("/api/quests/nearby")
                .param("lat", "37.5665").param("lng", "126.9780")
                .param("radiusKm", String.valueOf(radiusKm))
                .header("Authorization", "Bearer " + token))
            .andExpect(status().isOk())
            .andReturn();

        return JsonPath.read(result.getResponse().getContentAsString(), "$.data.quests[*].distanceM");
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
