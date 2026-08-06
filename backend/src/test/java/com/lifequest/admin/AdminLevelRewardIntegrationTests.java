package com.lifequest.admin;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
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
class AdminLevelRewardIntegrationTests {
    private static final AtomicInteger SEQUENCE = new AtomicInteger();

    @Autowired MockMvc mockMvc;
    @Autowired JdbcTemplate jdbcTemplate;

    @Test
    void normalUserCannotManageLevelRewards() throws Exception {
        String token = token(false);
        mockMvc.perform(get("/api/admin/level-rewards")
                        .header("Authorization", bearer(token)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));
    }

    @Test
    void adminCanUseCatalogAndManageLevelRewardConfiguration() throws Exception {
        String token = token(true);
        mockMvc.perform(get("/api/admin/level-rewards/catalog")
                        .header("Authorization", bearer(token)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.titles.length()").value(3))
                .andExpect(jsonPath("$.data.profileItems.length()").value(17));

        MvcResult created = mockMvc.perform(post("/api/admin/level-rewards")
                        .header("Authorization", bearer(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"level":10,"rewardType":"TITLE","rewardRefId":1,
                                 "description":"레벨 10 칭호"}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.rewardCode").value("NEW_ADVENTURER"))
                .andReturn();
        Number rewardId = JsonPath.read(created.getResponse().getContentAsString(), "$.data.id");

        mockMvc.perform(patch("/api/admin/level-rewards/{id}", rewardId.longValue())
                        .header("Authorization", bearer(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"level":11,"rewardType":"PROFILE_ITEM","rewardRefId":1,
                                 "description":"레벨 11 배지"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.level").value(11))
                .andExpect(jsonPath("$.data.rewardCode").value("SPROUT_BADGE"));

        mockMvc.perform(delete("/api/admin/level-rewards/{id}", rewardId.longValue())
                        .header("Authorization", bearer(token)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.deleted").value(true));
    }

    @Test
    void duplicateAndMissingRewardReferencesAreRejected() throws Exception {
        String token = token(true);
        mockMvc.perform(post("/api/admin/level-rewards")
                        .header("Authorization", bearer(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"level":1,"rewardType":"TITLE","rewardRefId":1}
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("CONFLICT"));

        mockMvc.perform(post("/api/admin/level-rewards")
                        .header("Authorization", bearer(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"level":20,"rewardType":"PROFILE_ITEM","rewardRefId":999999}
                                """))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("RESOURCE_NOT_FOUND"));
    }

    private String token(boolean admin) throws Exception {
        int sequence = SEQUENCE.incrementAndGet();
        String email = "level-reward-admin-%d@lifequest.test".formatted(sequence);
        String nickname = "보상관리%d".formatted(sequence);
        mockMvc.perform(post("/api/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"password123","nickname":"%s"}
                                """.formatted(email, nickname)))
                .andExpect(status().isCreated());
        if (admin) jdbcTemplate.update("UPDATE users SET role = 'ADMIN' WHERE email = ?", email);
        MvcResult login = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"password123"}
                                """.formatted(email)))
                .andExpect(status().isOk())
                .andReturn();
        return JsonPath.read(login.getResponse().getContentAsString(), "$.data.accessToken");
    }

    private String bearer(String token) {
        return "Bearer " + token;
    }
}
