package com.lifequest.quest;

import com.jayway.jsonpath.JsonPath;
import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.growth.ExpLogRepository;
import com.lifequest.quest.domain.*;
import com.lifequest.quest.dto.QuestCompletionRequest;
import com.lifequest.quest.repository.QuestCompletionRepository;
import com.lifequest.quest.repository.QuestRepository;
import com.lifequest.quest.repository.UserDailyQuestRepository;
import com.lifequest.quest.service.QuestCompletionService;
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 완료 API가 계약대로 응답하는지 고정한다. 계약 원본은 {@code docs/04-api-spec.md} §4.
 *
 * <p>실구현({@code QuestCompletionServiceImpl})을 리포지토리 픽스처(Quest·UserDailyQuest 직접
 * 생성)로 검증한다. 팀원이 이 응답에 맞춰 완료 화면의 분기(중복 완료·반경 밖·만료·정확도)를
 * 만들기 때문에, 여기가 깨지면 그 오류가 클라이언트로 그대로 전파된다.
 *
 * <p>만료 04:00 일자 경계({@code docs/05-business-rules.md} §1-1)는 {@code expiresAt}을
 * 계산하는 배정 로직 확인이 먼저 필요해 이 파일에 아직 없다.
 *
 * <p>테스트마다 다른 이메일·배정을 써서 DB에 남는 상태가 서로 섞이지 않게 한다.
 */
@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
class QuestCompletionContractTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private QuestRepository questRepository;

    @Autowired
    private UserDailyQuestRepository userDailyQuestRepository;

    @Autowired
    private UserRepository userRepository;
    @Autowired
    private QuestCompletionRepository questCompletionRepository;
    @Autowired
    private QuestCompletionService questCompletionService;
    @Autowired
    private Clock clock;
    @Autowired
    private ExpLogRepository expLogRepository;

    @Test
    void
    완료하면_결과와_스텁_표식이_함께_온다() throws Exception {
        String token = signUpAndGetAccessToken("complete@lifequest.test", "완료모험가");
        long dailyQuestId = assignLocationQuest(
            "complete@lifequest.test", 37.5665, 126.9780, 100, LocalDateTime.now().plusDays(1));

        mockMvc.perform(complete(dailyQuestId, token, """
                {"latitude": 37.5665, "longitude": 126.9780, "accuracy": 12.5}
                """))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.success").value(true))
            .andExpect(jsonPath("$.data.duplicated").value(false))
            .andExpect(jsonPath("$.data.completionId").isNumber())
            .andExpect(jsonPath("$.data.location.distanceM").isNotEmpty());
    }

    @Test
    void 두번째_완료는_오류가_아니라_재지급_없는_현재_상태다() throws Exception {
        String token = signUpAndGetAccessToken("dup@lifequest.test", "중복모험가");
        long dailyQuestId = assignLocationQuest(
            "dup@lifequest.test", 37.5665, 126.9780, 100, LocalDateTime.now().plusDays(1));
        String body = """
            {"latitude": 37.5665, "longitude": 126.9780, "accuracy": 12.5}
            """;

        MvcResult first = mockMvc.perform(complete(dailyQuestId, token, body))
            .andExpect(status().isOk())
            .andReturn();
        int completionId =
            JsonPath.read(first.getResponse().getContentAsString(), "$.data.completionId");

        // 계약: HTTP 200 · 같은 completionId · 어떤 보상도 재지급하지 않는다.
        // 오류로 처리하면 앱이 "완료 실패"를 띄워, 이미 받은 완료를 사용자가 의심하게 된다.
        mockMvc.perform(complete(dailyQuestId, token, body))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.duplicated").value(true))
            .andExpect(jsonPath("$.data.completionId").value(completionId))
            .andExpect(jsonPath("$.data.growth.expGained").value(0))
            .andExpect(jsonPath("$.data.growth.levelUp").value(false))
            .andExpect(jsonPath("$.data.growth.rewards").isEmpty())
            .andExpect(jsonPath("$.data.collection.newLifedexItems").isEmpty())
            .andExpect(jsonPath("$.data.collection.newAchievements").isEmpty());
    }

    @Test
    void 반경_밖이면_현재_거리를_함께_알린다() throws Exception {
        String token = signUpAndGetAccessToken("radius@lifequest.test", "반경모험가");
        long dailyQuestId = assignLocationQuest(
            "radius@lifequest.test", 37.5665, 126.9780, 50, LocalDateTime.now().plusDays(1));

        MvcResult result = mockMvc.perform(complete(dailyQuestId, token, """
                {"latitude": 37.5000, "longitude": 126.9000, "accuracy": 10.0}
                """))
            .andExpect(status().isUnprocessableContent())
            .andExpect(jsonPath("$.error.code").value("OUT_OF_RADIUS"))
            .andReturn();

        // 계약은 "반경 밖"만이 아니라 현재 거리까지 요구한다. 앱은 이 코드에서 서버
        // 메시지가 있으면 그대로 보여주므로, 거리가 빠지면 기본 문구로 떨어진다.
        String message = JsonPath.read(result.getResponse().getContentAsString(), "$.error.message");
        assertThat(message).containsPattern("\\d+\\s*m");
    }

    @Test
    void 만료된_배정은_완료할_수_없다() throws Exception {
        String token = signUpAndGetAccessToken("expired@lifequest.test", "만료모험가");
        long dailyQuestId = assignLocationQuest(
            "expired@lifequest.test", 37.5665, 126.9780, 100, LocalDateTime.now().minusDays(1));

        mockMvc.perform(complete(dailyQuestId, token, """
                {"latitude": 37.5665, "longitude": 126.9780, "accuracy": 12.5}
                """))
            .andExpect(status().isConflict())
            .andExpect(jsonPath("$.error.code").value("QUEST_EXPIRED"));
    }

    @Test
    void 위치_퀘스트에_좌표가_없으면_검증_실패가_아니라_위치_요구다() throws Exception {
        String token = signUpAndGetAccessToken("noloc@lifequest.test", "좌표없는모험가");
        long dailyQuestId = assignLocationQuest(
            "noloc@lifequest.test", 37.5665, 126.9780, 100, LocalDateTime.now().plusDays(1));

        // 일반 VALIDATION_FAILED 로 나가면 앱이 권한·정확도 유도 화면을 띄울 수 없다.
        // 본문 없이 호출하는 것은 SELF_REPORT 퀘스트의 정상 경로이기도 하다.
        mockMvc.perform(post("/api/daily-quests/{id}/complete", dailyQuestId)
                .header("Authorization", "Bearer " + token))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.error.code").value("LOCATION_REQUIRED"));
    }

    @Test
    void 정확도가_기준보다_낮으면_거절한다() throws Exception {
        String token = signUpAndGetAccessToken("acc@lifequest.test", "정확도모험가");
        long dailyQuestId = assignLocationQuest(
            "acc@lifequest.test", 37.5665, 126.9780, 100, LocalDateTime.now().plusDays(1));

        mockMvc.perform(complete(dailyQuestId, token, """
                {"latitude": 37.5665, "longitude": 126.9780, "accuracy": 120.0}
                """))
            .andExpect(status().isUnprocessableContent())
            .andExpect(jsonPath("$.error.code").value("LOCATION_ACCURACY_TOO_LOW"));
    }

    @Test
    void 남의_배정을_완료하려_하면_RESOURCE_NOT_FOUND() throws Exception {
        // 퀘스트와 그 오너 등록
        String signUpEmail = "owner1@lifequest.test";
        signUpAndGetAccessToken(signUpEmail, "소유권모험가");
        long dailyQuestId = assignSelfReportQuest(
            signUpEmail, LocalDateTime.now().plusDays(1));

        // 다른 사람 등록 후 완료 시도
        String otherToken = signUpAndGetAccessToken("other@lifequest.test", "다른소유권모험가");
        mockMvc.perform(complete(dailyQuestId, otherToken, ""))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.error.code").value("RESOURCE_NOT_FOUND"));
    }

    @Test
    void 완료_기록은_uk_quest_completions_udq로_유일하게_보장된다() throws Exception {
        String signUpEmail = "owner2@lifequest.test";
        signUpAndGetAccessToken(signUpEmail, "멱등모험가");
        long dailyQuestId = assignSelfReportQuest(
            signUpEmail, LocalDateTime.now().plusDays(1));
        UserDailyQuest userDailyQuest = userDailyQuestRepository.findById(dailyQuestId)
            .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));

        questCompletionRepository.saveAndFlush(
            new QuestCompletion(
                userDailyQuest,
                null,
                null,
                null,
                null,
                LocalDateTime.now(clock)
            ));

        assertThrows(
            DataIntegrityViolationException.class,
            () -> {
                questCompletionRepository.saveAndFlush(
                    new QuestCompletion(
                        userDailyQuest,
                        null,
                        null,
                        null,
                        null,
                        LocalDateTime.now(clock)));
            }
        );
    }

    @Test
    void EXP_재지급_2차_방어선의_전제가_맞다() throws Exception {
        String signUpEmail = "owner3@lifequest.test";
        signUpAndGetAccessToken(signUpEmail, "중복지급모험가");

        long userId = userRepository.findByEmailIgnoreCase(signUpEmail)
            .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND))
            .getId();

        Long completionId = questCompletionService.complete(
                userId,
                assignSelfReportQuest(signUpEmail, LocalDateTime.now().plusDays(1)),
                QuestCompletionRequest.empty())
            .completionId();

        assertThat(
            expLogRepository.existsByUserIdAndSourceTypeAndSourceId(
                userId,
                "QUEST_COMPLETION",
                completionId))
            .isTrue();
    }

    @Test
    void growth_totalExp는_완료_전_값과_expGained의_합이다() throws Exception {
        String signUpEmail = "owner4@lifequest.test";
        signUpAndGetAccessToken(signUpEmail, "경험치모험가");

        long userId = userRepository.findByEmailIgnoreCase(signUpEmail)
            .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND))
            .getId();

        long userDailyQuestId = assignSelfReportQuest(signUpEmail, LocalDateTime.now().plusDays(1));
        UserDailyQuest userDailyQuest = userDailyQuestRepository.findById(userDailyQuestId)
            .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));

        int expReward = questRepository.findById(userDailyQuest.getQuestId())
            .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND))
            .getExpReward();

        int before = userRepository.findById(userId)
            .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND))
            .getTotalExp();

        questCompletionService.complete(
            userId,
            userDailyQuestId,
            QuestCompletionRequest.empty());

        assertThat(
            userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND))
                .getTotalExp())
            .isEqualTo(before + expReward);
    }

    @Test
    void 반경_경계값에서_거리_계산이_정확하다() throws Exception {
        // 구글 어스(https://earth.google.com/) 기준으로 좌표 획득
        // 거리 계산 출처: https://movable-type.co.uk/scripts/latlong.html

        // 기준 지점: 부산광역시 동래구 충렬대로107번길 124 온천초등학교
        // 35.21232399, 129.07369607
        final double TARGET_LAT = 35.21232399;
        final double TARGET_LON = 129.07369607;

        // 목표 지점 기준 허용 반경
        final int RADIUS_M = 100;

        // 타겟1: 부산광역시 동래구 온천동 784-18번지 가람도서  (온천초등학교로부터 63.51)
        // 35.21216056, 129.07302618
        final BigDecimal REPORTED_LAT1 = BigDecimal.valueOf(35.21216056);
        final BigDecimal REPORTED_LON1 = BigDecimal.valueOf(129.07302618);

        // 타겟2: 부산광역시 동래구 온천동 784-33 청궁사 (온천초등학교로부터 114.2)
        // 35.21183846, 129.07258842
        final BigDecimal REPORTED_LAT2 = BigDecimal.valueOf(35.21183846);
        final BigDecimal REPORTED_LON2 = BigDecimal.valueOf(129.07258842);

        String email = "boundary@lifequest.test";
        String token = signUpAndGetAccessToken(email, "경계모험가");


        // 온천초등학교로부터 63.51 < 100m. 명백히 반경 내
        long onBoundaryId = assignLocationQuest(email, TARGET_LAT, TARGET_LON, RADIUS_M, LocalDateTime.now().plusDays(1));
        mockMvc.perform(
                complete(
                    onBoundaryId,
                    token,
                    """
                            {"latitude": %s, "longitude": %s, "accuracy": 10.0}
                        """.formatted(REPORTED_LAT1, REPORTED_LON1)))
            .andExpect(status().isOk());

        // 온천초등학교로부터 114.2m > 100m. 명백히 반경 외, OUT_OF_RADIUS여야 한다
        long overBoundaryId = assignLocationQuest(email, TARGET_LAT, TARGET_LON, RADIUS_M, LocalDateTime.now().plusDays(1));
        mockMvc.perform(
                complete(
                    overBoundaryId,
                    token,
                    """
                        {"latitude": %s, "longitude": %s, "accuracy": 10.0}
                        """.formatted(REPORTED_LAT2, REPORTED_LON2)))
            .andExpect(status().isUnprocessableContent())
            .andExpect(jsonPath("$.error.code").value("OUT_OF_RADIUS"));
    }

    @Test
    void SELF_REPORT_퀘스트는_좌표_없이_완료된다() throws Exception {
        String signUpEmail = "owner5@lifequest.test";
        String token = signUpAndGetAccessToken(signUpEmail, "자체_보고_모험가");
        long dailyQuestId = assignSelfReportQuest(
            signUpEmail, LocalDateTime.now().plusDays(1));

        mockMvc.perform(complete(dailyQuestId, token, ""))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.duplicated").value(false));
    }

    @Test
    @Disabled("팀원3 CollectionService 실구현 대기")
        // TODO(팀원3 착수 전 확인): 지금은 PlaceholderCollectionService가 항상 빈 결과를 반환해
        // 이 테스트가 픽스처 없이도(9004L 자체가 실 배정이 아니라) status().isOk()에서부터 실패한다.
        // 실구현을 붙일 때 CollectionService.java의 TODO(보상을 growth.rewards에 실을 경로 없음)를
        // 먼저 확인할 것 — 안 그러면 이 테스트의 growth.rewards[0] 단언이 또 막힌다.
    void 비밀_업적은_해금_표식과_함께_실려_온다() throws Exception {
        String token = signUpAndGetAccessToken("secret@lifequest.test", "비밀모험가");

        // 앱은 이 표식으로 완료 결과 위에 모달을 겹칠지 정한다(S-17). 계약 예시에는
        // 없던 필드라, 빠지면 모달이 한 번도 뜨지 않는다.
        mockMvc.perform(complete(9004L, token, """
                {"latitude": 37.5665, "longitude": 126.9780, "accuracy": 12.5}
                """))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.collection.newAchievements[0].secret").value(true))
            .andExpect(jsonPath("$.data.growth.levelUp").value(true))
            // 보상은 이름만이 아니라 종류·코드까지 실린다 — 이름만으로는 앱이
            // 칭호와 프로필 아이템을 구분하지 못한다.
            .andExpect(jsonPath("$.data.growth.rewards[0].type").value("TITLE"))
            .andExpect(jsonPath("$.data.growth.rewards[0].code").isNotEmpty());
    }

    private MockHttpServletRequestBuilder complete(
        long dailyQuestId, String token, String body) {
        return post("/api/daily-quests/{id}/complete", dailyQuestId)
            .header("Authorization", "Bearer " + token)
            .contentType(MediaType.APPLICATION_JSON)
            .content(body);
    }

    /**
     * LOCATION 퀘스트를 만들고 해당 사용자에게 배정한다. 반환값은 완료 요청 대상인
     * {@code UserDailyQuest.id} — {@code IDENTITY} 자동생성이라 시나리오 리터럴로 고정할 수 없다.
     */
    private long assignLocationQuest(
        String email, double latitude, double longitude, int radiusM, LocalDateTime expiresAt) {
        User user = userRepository.findByEmailIgnoreCase(email)
            .orElseThrow(() -> new IllegalStateException("픽스처 대상 사용자가 없다: " + email));

        Quest quest = questRepository.save(new Quest(
            "테스트용 위치 퀘스트", "계약 테스트 픽스처", QuestGrade.NORMAL, QuestCadence.DAILY,
            CompletionType.LOCATION, 50, "테스트 장소",
            BigDecimal.valueOf(latitude), BigDecimal.valueOf(longitude), radiusM,
            null, QuestCreator.SYSTEM, true));

        UserDailyQuest assignment = userDailyQuestRepository.save(
            new UserDailyQuest(user.getId(), quest.getId(), LocalDate.now(), expiresAt));

        return assignment.getId();
    }

    /**
     * SELF_REPORT 퀘스트를 만들고 해당 사용자에게 배정한다. 반환값은 완료 요청 대상인
     * {@code UserDailyQuest.id} — {@code IDENTITY} 자동생성이라 시나리오 리터럴로 고정할 수 없다.
     */
    private long assignSelfReportQuest(
        String email, LocalDateTime expiresAt) {
        User user = userRepository.findByEmailIgnoreCase(email)
            .orElseThrow(() -> new IllegalStateException("픽스처 대상 사용자가 없다: " + email));

        Quest quest = questRepository.save(new Quest(
            "테스트용 보고 퀘스트", "계약 테스트 픽스처", QuestGrade.NORMAL, QuestCadence.DAILY,
            CompletionType.SELF_REPORT, 50,
            null, null, null, null, null,
            QuestCreator.SYSTEM, true));

        UserDailyQuest assignment = userDailyQuestRepository.save(
            new UserDailyQuest(user.getId(), quest.getId(), LocalDate.now(), expiresAt));

        return assignment.getId();
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
