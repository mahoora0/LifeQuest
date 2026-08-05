package com.lifequest.auth;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.mock.web.MockMultipartFile;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;

@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
class AuthFlowIntegrationTests {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void localAuthProfileAndRefreshTokenRotationWorkTogether() throws Exception {
        String email = "flow@lifequest.test";

        mockMvc.perform(post("/api/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "%s",
                                  "password": "password123",
                                  "nickname": "첫모험가"
                                }
                                """.formatted(email)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.email").value(email));

        mockMvc.perform(post("/api/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "%s",
                                  "password": "password123",
                                  "nickname": "다른모험가"
                                }
                                """.formatted(email)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("DUPLICATE_EMAIL"));

        MvcResult login = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"password123"}
                                """.formatted(email)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.expiresIn").value(900))
                .andReturn();

        String loginBody = login.getResponse().getContentAsString();
        String accessToken = JsonPath.read(loginBody, "$.data.accessToken");
        String refreshToken = JsonPath.read(loginBody, "$.data.refreshToken");

        mockMvc.perform(get("/api/users/me")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.nickname").value("첫모험가"));

        mockMvc.perform(patch("/api/users/me")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "nickname":"수정모험가"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.nickname").value("수정모험가"));

        mockMvc.perform(get("/api/users/me/characters")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(4))
                .andExpect(jsonPath("$.data[0].requiredLevel").value(1))
                .andExpect(jsonPath("$.data[0].unlocked").value(true))
                .andExpect(jsonPath("$.data[1].requiredLevel").value(5))
                .andExpect(jsonPath("$.data[1].unlocked").value(false));

        mockMvc.perform(patch("/api/users/me/character")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"characterId":2}
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("CHARACTER_LOCKED"));

        mockMvc.perform(get("/api/users/me/accessories")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.accessories.length()").value(14))
                .andExpect(jsonPath("$.data.accessories[0].requiredLevel").doesNotExist())
                .andExpect(jsonPath("$.data.accessories[0].unlocked").value(false))
                .andExpect(jsonPath("$.data.selectedAccessoryId").doesNotExist());

        mockMvc.perform(patch("/api/users/me/accessory")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"accessoryId":4}
                                """))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/users/me/titles")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.titles[0].name").value("새내기 모험가"))
                .andExpect(jsonPath("$.data.representativeTitleId").value(1));

        mockMvc.perform(get("/api/users/me/badges")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.badges[0].name").value("새싹 배지"))
                .andExpect(jsonPath("$.data.representativeBadgeId").value(1));

        mockMvc.perform(patch("/api/users/me/title")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"titleId":null}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.representativeTitle").doesNotExist());

        mockMvc.perform(patch("/api/users/me/title")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"titleId":1}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.representativeTitle.name")
                        .value("새내기 모험가"));

        mockMvc.perform(patch("/api/users/me/badge")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"badgeId":null}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.representativeBadge").doesNotExist());

        mockMvc.perform(patch("/api/users/me/badge")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"badgeId":1}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.representativeBadge.name").value("새싹 배지"));

        MockMultipartFile profileImage = new MockMultipartFile(
                "file", "profile.png", "image/png", new byte[] {1, 2, 3});
        MvcResult upload = mockMvc.perform(multipart("/api/users/me/profile-image")
                        .file(profileImage)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.profileImageUrl")
                        .value(org.hamcrest.Matchers.startsWith("/uploads/profile/")))
                .andReturn();
        String profileImageUrl = JsonPath.read(
                upload.getResponse().getContentAsString(),
                "$.data.profileImageUrl");
        mockMvc.perform(get(profileImageUrl))
                .andExpect(status().isOk());

        mockMvc.perform(delete("/api/users/me/profile-image")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.profileImageUrl").doesNotExist());

        MockMultipartFile invalidImage = new MockMultipartFile(
                "file", "profile.txt", "text/plain", new byte[] {1, 2, 3});
        mockMvc.perform(multipart("/api/users/me/profile-image")
                        .file(invalidImage)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("INVALID_PROFILE_IMAGE"));

        mockMvc.perform(patch("/api/users/me/badge")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"badgeId":2}
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));

        MvcResult reissue = mockMvc.perform(post("/api/auth/reissue")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(refreshToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.data.refreshToken").isNotEmpty())
                .andReturn();

        String rotatedRefreshToken = JsonPath.read(
                reissue.getResponse().getContentAsString(),
                "$.data.refreshToken");
        org.junit.jupiter.api.Assertions.assertNotEquals(refreshToken, rotatedRefreshToken);

        mockMvc.perform(post("/api/auth/reissue")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(refreshToken)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("TOKEN_EXPIRED"));
    }

    @Test
    void protectedEndpointUsesTheCommonErrorEnvelope() throws Exception {
        mockMvc.perform(get("/api/users/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
    }

    @Test
    void googleLoginExplainsWhenOAuthIsNotConfigured() throws Exception {
        mockMvc.perform(post("/api/auth/google")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"idToken":"not-a-real-token"}
                                """))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.error.code")
                        .value("AUTH_PROVIDER_NOT_CONFIGURED"));
    }
}
