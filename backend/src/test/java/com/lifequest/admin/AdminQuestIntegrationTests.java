package com.lifequest.admin;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.lifequest.quest.domain.QuestCreator;
import com.lifequest.quest.repository.QuestRepository;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
class AdminQuestIntegrationTests {
    private static final AtomicInteger SEQUENCE = new AtomicInteger();

    @Autowired MockMvc mockMvc;
    @Autowired JdbcTemplate jdbcTemplate;
    @Autowired QuestRepository questRepository;

    @Test
    void normalUserCannotAccessAdminQuestApis() throws Exception {
        Account user = account("일반관리화면", false);
        mockMvc.perform(get("/api/admin/quests")
                        .header("Authorization", bearer(user.token())))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));
    }

    @Test
    void adminCanCreateListUpdateAndSoftDeleteQuest() throws Exception {
        Account admin = account("퀘스트관리자", true);

        MvcResult created = mockMvc.perform(post("/api/admin/quests")
                        .header("Authorization", bearer(admin.token()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"관리자 산책","description":"동네를 걸어요",
                                 "grade":"RARE","cadence":"WEEKLY",
                                 "completionType":"SELF_REPORT","expReward":40}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.createdBy").value("ADMIN"))
                .andExpect(jsonPath("$.data.active").value(true))
                .andReturn();
        Number questId = JsonPath.read(created.getResponse().getContentAsString(), "$.data.id");

        mockMvc.perform(get("/api/admin/quests")
                        .header("Authorization", bearer(admin.token()))
                        .queryParam("page", "0").queryParam("size", "100"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content[?(@.id == %d)]".formatted(
                        questId.longValue())).exists());

        mockMvc.perform(patch("/api/admin/quests/{questId}", questId.longValue())
                        .header("Authorization", bearer(admin.token()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"수정된 관리자 산책","grade":"EPIC","expReward":80}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.title").value("수정된 관리자 산책"))
                .andExpect(jsonPath("$.data.grade").value("EPIC"))
                .andExpect(jsonPath("$.data.expReward").value(80));

        mockMvc.perform(delete("/api/admin/quests/{questId}", questId.longValue())
                        .header("Authorization", bearer(admin.token())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.questId").value(questId.longValue()))
                .andExpect(jsonPath("$.data.deactivated").value(true));

        var stored = questRepository.findById(questId.longValue()).orElseThrow();
        org.assertj.core.api.Assertions.assertThat(stored.getCreatedBy())
                .isEqualTo(QuestCreator.ADMIN);
        org.assertj.core.api.Assertions.assertThat(stored.isActive()).isFalse();
    }

    @Test
    void adminQuestValidationChecksGradeRewardAndLocationFields() throws Exception {
        Account admin = account("검증관리자", true);

        mockMvc.perform(post("/api/admin/quests")
                        .header("Authorization", bearer(admin.token()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"보상 오류","grade":"NORMAL","cadence":"DAILY",
                                 "completionType":"SELF_REPORT","expReward":100}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_FAILED"));

        mockMvc.perform(post("/api/admin/quests")
                        .header("Authorization", bearer(admin.token()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"위치 누락","grade":"RARE","cadence":"DAILY",
                                 "completionType":"LOCATION","expReward":40,
                                 "placeName":"서울숲"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_FAILED"));
    }

    private Account account(String prefix, boolean admin) throws Exception {
        int sequence = SEQUENCE.incrementAndGet();
        String email = "admin-quest-%d@lifequest.test".formatted(sequence);
        String nickname = "%s%d".formatted(prefix, sequence);
        mockMvc.perform(post("/api/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"password123","nickname":"%s"}
                                """.formatted(email, nickname)))
                .andExpect(status().isCreated());
        if (admin) {
            jdbcTemplate.update("UPDATE users SET role = 'ADMIN' WHERE email = ?", email);
        }
        MvcResult login = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"password123"}
                                """.formatted(email)))
                .andExpect(status().isOk())
                .andReturn();
        String token = JsonPath.read(login.getResponse().getContentAsString(), "$.data.accessToken");
        return new Account(token);
    }

    private String bearer(String token) {
        return "Bearer " + token;
    }

    private record Account(String token) {
    }
}
