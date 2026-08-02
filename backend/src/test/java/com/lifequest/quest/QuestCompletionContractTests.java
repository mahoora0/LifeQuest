package com.lifequest.quest;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 완료 API가 계약대로 응답하는지 고정한다. 계약 원본은 {@code docs/04-api-spec.md} §4.
 *
 * <p>지금 응답하는 것은 스텁이지만 검증 대상은 <b>계약</b>이다. 팀원이 이 응답에 맞춰
 * 완료 화면의 분기(중복 완료·반경 밖·만료·정확도)를 만들기 때문에, 스텁이 계약을 어기면
 * 그 오류가 클라이언트로 전파되고 실구현이 와도 이미 틀어진 채로 굳는다.
 *
 * <p>실구현으로 교체할 때 이 파일은 <b>지우지 않는다.</b> 스텁이 사라져도 계약은 그대로라,
 * 오히려 여기가 실구현이 계약을 지키는지 보는 첫 그물이 된다.
 *
 * <h2>이 테스트가 보장하지 못하는 것</h2>
 *
 * 여기서 보는 것은 <b>계약의 모양</b>뿐이다. 실제 트랜잭션·멱등·위치 판정은 하나도
 * 검증하지 않는다. 스텁에는 DB도 거리 계산도 없기 때문이다. 아래는 실구현과 함께
 * 붙여야 하며, 지금 넣으면 <b>항상 통과하는 가짜 테스트</b>가 된다.
 *
 * <ul>
 *   <li>TODO(impl): 소유권 — 남의 배정을 완료하려 하면 {@code RESOURCE_NOT_FOUND}.
 *       스텁이 {@code userId}를 쓰지 않아 지금 검증하면 무조건 통과한다
 *   <li>TODO(impl): 멱등의 근거 — 동시 요청에서도 완료 기록이 하나뿐인지.
 *       보장은 {@code uk_quest_completions_udq}가 하므로 DB 없이는 확인할 수 없다
 *   <li>TODO(impl): EXP 재지급 2차 방어선 — {@code exp_logs}의
 *       {@code UNIQUE(user_id, source_type, source_id)}에 {@code completionId}가 실리는지.
 *       <b>{@code source_type} 값도 함께 본다</b> — 이 제약은 정상 경로에서 한 번도
 *       발동하지 않으므로(중복 완료는 지급을 시도조차 하지 않는다) 문자열이 어긋나도
 *       조용하다. 볼 것은 방어선의 <b>발동</b>이 아니라 <b>전제</b>다
 *   <li>TODO(impl): {@code growth.totalExp}가 완료 전 값 + {@code expGained}와 같은지.
 *       앱이 이 필드를 파싱만 하고 화면에는 쓰지 않아(기본값 0) <b>틀려도 어디서도
 *       드러나지 않는다</b>
 *   <li>TODO(impl): 거리 계산이 실제로 맞는지(Haversine 경계값). 지금은 메시지에 숫자가
 *       있는지만 본다
 *   <li>TODO(impl): 만료 판정이 04:00 일자 경계를 따르는지
 *       ({@code docs/05-business-rules.md} §1-1)
 *   <li>TODO(impl): 정확도 임계값이 규칙서(§3)와 같은 값인지. 스텁은 자체 상수를 쓴다
 *   <li>TODO(impl): {@code completion_type}에 따른 분기 — {@code SELF_REPORT}는 좌표
 *       없이 완료되고 {@code LOCATION}만 좌표를 요구하는지
 * </ul>
 *
 * <p>스텁이 인메모리 싱글톤이라 테스트 사이에 상태가 남는다. 완료가 기록되는 시나리오는
 * 테스트마다 다른 배정 ID를 쓴다.
 */
@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
class QuestCompletionContractTests {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void 완료하면_결과와_스텁_표식이_함께_온다() throws Exception {
        String token = signUpAndGetAccessToken("complete@lifequest.test", "완료모험가");

        mockMvc.perform(complete(7001L, token, """
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
        String body = """
                {"latitude": 37.5665, "longitude": 126.9780, "accuracy": 12.5}
                """;

        MvcResult first = mockMvc.perform(complete(7002L, token, body))
                .andExpect(status().isOk())
                .andReturn();
        int completionId =
                JsonPath.read(first.getResponse().getContentAsString(), "$.data.completionId");

        // 계약: HTTP 200 · 같은 completionId · 어떤 보상도 재지급하지 않는다.
        // 오류로 처리하면 앱이 "완료 실패"를 띄워, 이미 받은 완료를 사용자가 의심하게 된다.
        mockMvc.perform(complete(7002L, token, body))
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

        MvcResult result = mockMvc.perform(complete(9002L, token, """
                        {"latitude": 37.5000, "longitude": 126.9000, "accuracy": 10.0}
                        """))
                .andExpect(status().isUnprocessableEntity())
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

        mockMvc.perform(complete(9001L, token, """
                        {"latitude": 37.5665, "longitude": 126.9780, "accuracy": 12.5}
                        """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("QUEST_EXPIRED"));
    }

    @Test
    void 위치_퀘스트에_좌표가_없으면_검증_실패가_아니라_위치_요구다() throws Exception {
        String token = signUpAndGetAccessToken("noloc@lifequest.test", "좌표없는모험가");

        // 일반 VALIDATION_FAILED 로 나가면 앱이 권한·정확도 유도 화면을 띄울 수 없다.
        // 본문 없이 호출하는 것은 SELF_REPORT 퀘스트의 정상 경로이기도 하다.
        mockMvc.perform(post("/api/daily-quests/{id}/complete", 9003L)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("LOCATION_REQUIRED"));
    }

    @Test
    void 정확도가_기준보다_낮으면_거절한다() throws Exception {
        String token = signUpAndGetAccessToken("acc@lifequest.test", "정확도모험가");

        mockMvc.perform(complete(7003L, token, """
                        {"latitude": 37.5665, "longitude": 126.9780, "accuracy": 120.0}
                        """))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.error.code").value("LOCATION_ACCURACY_TOO_LOW"));
    }

    @Test
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
