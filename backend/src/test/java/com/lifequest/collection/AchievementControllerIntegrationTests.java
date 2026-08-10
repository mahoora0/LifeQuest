package com.lifequest.collection;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
class AchievementControllerIntegrationTests {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void achievementEndpointsReturnCatalogAndMyProgress() throws Exception {
        mockMvc.perform(get("/api/achievements")
                        .with(jwt().jwt(token -> token.subject("993"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.achievements.length()").value(11))
                .andExpect(jsonPath("$.data.achievements[0].name").value("모험의 발자국"))
                .andExpect(jsonPath("$.data.achievements[6].secret").value(true))
                .andExpect(jsonPath("$.data.achievements[6].name").value(""));

        mockMvc.perform(get("/api/users/me/achievements")
                        .with(jwt().jwt(token -> token.subject("993"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.achievements.length()").value(11))
                .andExpect(jsonPath("$.data.achievements[0].currentValue").value(0))
                .andExpect(jsonPath("$.data.achievements[0].requiredValue").value(1));
    }
}
