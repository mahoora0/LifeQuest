package com.lifequest.quest;

import com.jayway.jsonpath.JsonPath;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.domain.UserDailyQuest;
import com.lifequest.quest.repository.QuestRepository;
import com.lifequest.quest.repository.UserDailyQuestRepository;
import com.lifequest.quest.service.QuestPeriod;
import com.lifequest.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 위치 퀘스트가 사용자 주변에서 배정되는지 고정한다(V32·V33).
 *
 * <p>이전에는 시드가 전부 서울이라 서울 밖 사용자의 슬롯 A가 완료 불가였다. 이제 배정이
 * 사용자 좌표로 후보를 좁히고, 주변에 시드된 도시가 없으면 장소 미지정 템플릿에 그 자리에서
 * 만든 좌표를 붙인다.
 *
 * <p><b>{@code @Transactional}을 붙이지 않는다.</b> 생성 트랜잭션이 {@code REQUIRES_NEW}라
 * 테스트 트랜잭션이 롤백돼도 배정은 커밋된다({@code QuestAssignmentContractTests}와 같은 이유).
 * 테스트마다 다른 이메일을 써서 사용자별로 상태를 가른다.
 *
 * <p>어떤 퀘스트가 뽑히는지는 확률이라 단언하지 않는다. 재는 것은 <b>뽑힌 것이 갈 수 있는
 * 거리에 있는가</b>다 — 그것이 이 변경이 만들려는 성질이고, 확률 추출을 고정하지 않고도 잰다.
 */
@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
class QuestLocationTargetingTests {

    /**
     * 트랙별 판정 반경(m). {@code QuestAssignmentCreator}의 값과 같다.
     *
     * <p>구현 상수를 import하지 않고 다시 적는다. 같은 값을 가져다 쓰면 그 값이 바뀔 때 테스트도
     * 함께 따라가 <b>무엇을 바꿨는지 아무도 모르게 통과</b>한다 — 여기 적힌 숫자는 계약이다.
     */
    private static final double DAILY_RADIUS_M = 15_000;
    private static final double WEEKLY_RADIUS_M = 50_000;

    private static final double SEOUL_LAT = 37.5665;
    private static final double SEOUL_LNG = 126.9780;
    private static final double BUSAN_LAT = 35.1796;
    private static final double BUSAN_LNG = 129.0756;

    /** 시드된 6개 도시 중 어느 곳에서도 50km 밖이다 — 가장 가까운 광주까지 약 185km. */
    private static final double JEJU_LAT = 33.4996;
    private static final double JEJU_LNG = 126.5312;

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserDailyQuestRepository userDailyQuestRepository;

    @Autowired
    private QuestRepository questRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private QuestPeriod questPeriod;

    /**
     * 서울 사용자에게는 서울 퀘스트가, 부산 사용자에게는 부산 퀘스트가 간다.
     *
     * <p>두 도시를 한 테스트에서 재는 이유는 <b>"가까운 것이 온다"와 "서울이 온다"를 구분</b>하기
     * 위해서다. 서울만 재면 필터가 아예 돌지 않아도 통과한다 — 시드 대부분이 서울이기 때문이다.
     */
    @Test
    void 배정된_위치_퀘스트는_사용자_생활권_안에_있다() throws Exception {
        assertAssignedLocationQuestsAreNear("target-seoul@lifequest.test", "서울탐험가",
            SEOUL_LAT, SEOUL_LNG);
        assertAssignedLocationQuestsAreNear("target-busan@lifequest.test", "부산탐험가",
            BUSAN_LAT, BUSAN_LNG);
    }

    /**
     * 주변에 시드된 도시가 없으면 템플릿이 배정되고, 좌표는 그 사용자 주변에 만들어진다.
     *
     * <p>여기서 빈 목록을 돌려주면 슬롯 A가 타입 완화로 넘어가 그 사용자는 위치 퀘스트를 영영
     * 받지 못한다 — 배정 개수만 세는 테스트로는 그 상태가 정상으로 보인다.
     */
    @Test
    void 주변에_시드된_도시가_없으면_템플릿에_현재_위치_기반_좌표가_붙는다() throws Exception {
        String email = "target-remote@lifequest.test";
        String token = signUpAndGetAccessToken(email, "제주탐험가");

        getToday(token, JEJU_LAT, JEJU_LNG);

        List<UserDailyQuest> assigned = assignmentsOf(email);
        List<UserDailyQuest> templates = assigned.stream()
            .filter(assignment -> questOf(assignment).isLocationTemplate())
            .toList();

        assertThat(templates)
            .as("주변에 시드된 장소가 없는 사용자에게는 템플릿이 배정되어야 한다 — "
                + "빈 목록을 돌려주면 슬롯 A가 타입 완화로 넘어가 위치 퀘스트가 영영 안 나온다")
            .isNotEmpty();

        for (UserDailyQuest assignment : templates) {
            Quest quest = questOf(assignment);

            assertThat(assignment.getOverrideLatitude())
                .as(quest.getTitle() + ": 템플릿인데 override 좌표가 없다 — "
                    + "자리표 좌표가 그대로 인증 지점이 되어 완료 불가가 된다")
                .isNotNull();

            double distance = haversineMeters(
                JEJU_LAT, JEJU_LNG,
                assignment.getOverrideLatitude().doubleValue(),
                assignment.getOverrideLongitude().doubleValue());

            assertThat(distance)
                .as("%s: 만들어진 지점이 사용자에게서 %.0fm 떨어져 있다 — "
                    .formatted(quest.getTitle(), distance)
                    + "반경 %dm의 20~80%% 안이어야 한다".formatted(quest.getRadiusM()))
                .isBetween(quest.getRadiusM() * 0.2, quest.getRadiusM() * 0.8);
        }
    }

    /**
     * 좌표를 보내지 않으면 템플릿은 배정되지 않는다.
     *
     * <p>템플릿의 좌표는 만들 기준이 있어야 정해진다. 기준 없이 배정하면 자리표(국토 중앙)가
     * 그대로 인증 지점이 되고, 그 좌표도 유효한 좌표라 예외 없이 조용히 완료 불가가 된다.
     */
    @Test
    void 좌표_없이_조회하면_템플릿은_배정되지_않는다() throws Exception {
        String email = "target-nocoord@lifequest.test";
        String token = signUpAndGetAccessToken(email, "무좌표탐험가");

        mockMvc.perform(get("/api/quests/today").header("Authorization", "Bearer " + token))
            .andExpect(status().isOk());

        assertThat(assignmentsOf(email))
            .as("좌표를 모르는 사용자에게 템플릿이 가면 자리표가 인증 지점이 된다")
            .noneMatch(assignment -> questOf(assignment).isLocationTemplate());
    }

    /**
     * 템플릿 퀘스트의 완료 판정은 원본 좌표가 아니라 그 배정에 붙은 좌표를 쓴다.
     *
     * <p>두 방향을 함께 잰다. override 지점에서 성공하는 것만 보면 원본 좌표로 재는 구현도
     * 통과할 수 있고(둘 다 반경 안일 리 없지만 판정이 어디를 보는지 드러나지 않는다),
     * 원본 좌표에서 실패하는 것만 보면 판정이 아예 안 도는 경우와 구분되지 않는다.
     */
    @Test
    void 템플릿_완료는_배정에_붙은_좌표로_판정한다() throws Exception {
        String email = "target-complete@lifequest.test";
        String token = signUpAndGetAccessToken(email, "완료탐험가");

        getToday(token, JEJU_LAT, JEJU_LNG);

        UserDailyQuest template = assignmentsOf(email).stream()
            .filter(assignment -> questOf(assignment).isLocationTemplate())
            .findFirst()
            .orElseThrow(() -> new AssertionError("템플릿 배정이 없어 완료 경로를 잴 수 없다"));

        Quest quest = questOf(template);

        // 원본 좌표(국토 중앙 자리표)는 제주에서 수백 km 밖이다. 판정이 그쪽을 보고 있으면
        // 여기서 성공해 버린다
        mockMvc.perform(completeRequest(token, template.getId(),
                quest.getLatitude().doubleValue(), quest.getLongitude().doubleValue()))
            .andExpect(status().isUnprocessableEntity())
            .andExpect(jsonPath("$.error.code").value("OUT_OF_RADIUS"));

        mockMvc.perform(completeRequest(token, template.getId(),
                template.getOverrideLatitude().doubleValue(),
                template.getOverrideLongitude().doubleValue()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.duplicated").value(false));
    }

    /**
     * 목록 응답의 좌표도 배정에 붙은 것이어야 한다.
     *
     * <p>판정만 override를 보고 화면이 원본을 보면, 사용자는 지도가 가리킨 곳에 서 있는데
     * 인증이 안 된다. 그 어긋남은 실제로 거기까지 가 본 사용자에게만 드러난다.
     */
    @Test
    void 응답의_좌표가_배정에_붙은_지점과_같다() throws Exception {
        String email = "target-response@lifequest.test";
        String token = signUpAndGetAccessToken(email, "응답탐험가");

        MvcResult result = getToday(token, JEJU_LAT, JEJU_LNG);

        UserDailyQuest template = assignmentsOf(email).stream()
            .filter(assignment -> questOf(assignment).isLocationTemplate())
            .findFirst()
            .orElseThrow(() -> new AssertionError("템플릿 배정이 없어 응답 좌표를 잴 수 없다"));

        // 필터 결과는 항상 배열이다 — 단건이어도 그렇다
        List<Double> responseLat = JsonPath.read(result.getResponse().getContentAsString(),
            "$.data.quests[?(@.dailyQuestId == %d)].quest.latitude".formatted(template.getId()));

        assertThat(responseLat)
            .as("응답에 그 배정이 없다 — 목록과 배정 테이블이 어긋났다")
            .hasSize(1);
        assertThat(responseLat.get(0))
            .as("응답 좌표가 배정 좌표와 다르다 — 화면과 판정이 다른 지점을 가리킨다")
            .isEqualTo(template.getOverrideLatitude().doubleValue());
    }

    private void assertAssignedLocationQuestsAreNear(
            String email, String nickname, double lat, double lng) throws Exception {
        String token = signUpAndGetAccessToken(email, nickname);
        getToday(token, lat, lng);

        List<UserDailyQuest> located = assignmentsOf(email).stream()
            .filter(assignment -> questOf(assignment).isLocationBased())
            .toList();

        assertThat(located)
            .as(nickname + ": 위치 퀘스트가 하나도 배정되지 않았다 — 슬롯 A가 비었다")
            .isNotEmpty();

        for (UserDailyQuest assignment : located) {
            Quest quest = questOf(assignment);
            double distance = haversineMeters(lat, lng,
                assignment.resolvedLatitude(quest).doubleValue(),
                assignment.resolvedLongitude(quest).doubleValue());
            double allowed = quest.getCadence() == QuestCadence.WEEKLY
                ? WEEKLY_RADIUS_M : DAILY_RADIUS_M;

            assertThat(distance)
                .as("%s에게 %s 퀘스트 %s(%s)가 배정됐는데 %.1fkm 떨어져 있다 — 허용은 %.0fkm다"
                    .formatted(nickname, quest.getCadence(), quest.getTitle(),
                        quest.getPlaceName(), distance / 1000, allowed / 1000))
                .isLessThanOrEqualTo(allowed);
        }
    }

    /** 검증용 거리 계산. 구현과 같은 공식을 쓰되 테스트가 직접 갖는다 — 구현을 불러 재면 서로를 증명한다. */
    private static double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
        double earthRadiusM = 6_371_000;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.pow(Math.sin(dLat / 2), 2)
            + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
            * Math.pow(Math.sin(dLon / 2), 2);
        return earthRadiusM * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    private MvcResult getToday(String token, double lat, double lng) throws Exception {
        return mockMvc.perform(get("/api/quests/today")
                .param("lat", String.valueOf(lat))
                .param("lng", String.valueOf(lng))
                .header("Authorization", "Bearer " + token))
            .andExpect(status().isOk())
            .andReturn();
    }

    private org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder completeRequest(
            String token, Long dailyQuestId, double lat, double lng) {
        return post("/api/daily-quests/{id}/complete", dailyQuestId)
            .header("Authorization", "Bearer " + token)
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"latitude": %s, "longitude": %s, "accuracy": 10.0}
                """.formatted(lat, lng));
    }

    private List<UserDailyQuest> assignmentsOf(String email) {
        Long userId = userRepository.findByEmailIgnoreCase(email).orElseThrow().getId();
        return userDailyQuestRepository.findByUserIdAndAssignedDate(userId, questPeriod.logicalDate());
    }

    private Quest questOf(UserDailyQuest assignment) {
        Optional<Quest> quest = questRepository.findById(assignment.getQuestId());
        return quest.orElseThrow(() -> new AssertionError(
            "배정이 가리키는 퀘스트가 없다: questId=" + assignment.getQuestId()));
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
