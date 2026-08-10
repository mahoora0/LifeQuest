package com.lifequest.admin;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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
import org.springframework.transaction.annotation.Transactional;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;

@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
@Transactional
class AdminOperationsIntegrationTests {
    private static final AtomicInteger SEQUENCE = new AtomicInteger();

    @Autowired MockMvc mockMvc;
    @Autowired JdbcTemplate jdbcTemplate;
    @PersistenceContext EntityManager entityManager;

    @Test
    void adminCanReadDashboardAndSearchPaginatedUsers() throws Exception {
        Account admin = account("운영관리자", true);
        Account user = account("검색모험가", false);

        mockMvc.perform(get("/api/admin/dashboard")
                        .header("Authorization", bearer(admin.token())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalUsers").isNumber())
                .andExpect(jsonPath("$.data.totalQuests").isNumber())
                .andExpect(jsonPath("$.data.popularQuests").isArray());

        MvcResult users = mockMvc.perform(get("/api/admin/users")
                        .header("Authorization", bearer(admin.token()))
                        .queryParam("query", user.nickname())
                        .queryParam("page", "0")
                        .queryParam("size", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content.length()").value(1))
                .andExpect(jsonPath("$.data.content[0].email").value(user.email()))
                .andExpect(jsonPath("$.data.totalPages").isNumber())
                .andReturn();
        Number userId = JsonPath.read(users.getResponse().getContentAsString(), "$.data.content[0].id");

        mockMvc.perform(get("/api/admin/users/{userId}", userId.longValue())
                        .header("Authorization", bearer(admin.token())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.nickname").value(user.nickname()))
                .andExpect(jsonPath("$.data.recentQuests").isArray())
                .andExpect(jsonPath("$.data.recentExp").isArray());
    }

    @Test
    void normalUserCannotReadOperationsData() throws Exception {
        Account user = account("일반사용자", false);
        mockMvc.perform(get("/api/admin/users").header("Authorization", bearer(user.token())))
                .andExpect(status().isForbidden());
        mockMvc.perform(get("/api/admin/dashboard").header("Authorization", bearer(user.token())))
                .andExpect(status().isForbidden());
    }

    private Account account(String prefix, boolean admin) throws Exception {
        int sequence = SEQUENCE.incrementAndGet();
        String email = "admin-operations-%d@lifequest.test".formatted(sequence);
        String nickname = "%s%d".formatted(prefix, sequence);
        mockMvc.perform(post("/api/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"password123","nickname":"%s"}
                                """.formatted(email, nickname)))
                .andExpect(status().isCreated());
        if (admin) {
            jdbcTemplate.update("UPDATE users SET role = 'ADMIN' WHERE email = ?", email);
            entityManager.clear();
        }
        MvcResult login = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"password123"}
                                """.formatted(email)))
                .andExpect(status().isOk()).andReturn();
        String token = JsonPath.read(login.getResponse().getContentAsString(), "$.data.accessToken");
        return new Account(email, nickname, token);
    }

    private String bearer(String token) { return "Bearer " + token; }
    private record Account(String email, String nickname, String token) {}
}
