package com.lifequest.notification;

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
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
class NotificationIntegrationTests {
    private static final AtomicInteger SEQUENCE = new AtomicInteger();

    @Autowired MockMvc mockMvc;

    @Test
    void friendRequestAndAcceptanceCreatePrivateReadableNotifications() throws Exception {
        Account sender = account("알림요청자");
        Account receiver = account("알림수신자");

        MvcResult sent = mockMvc.perform(post("/api/friends/requests")
                        .header("Authorization", bearer(sender.token()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"receiverId":%d}
                                """.formatted(receiver.id())))
                .andExpect(status().isCreated())
                .andReturn();
        Number requestId = JsonPath.read(sent.getResponse().getContentAsString(), "$.data.requestId");

        MvcResult feed = mockMvc.perform(get("/api/notifications")
                        .header("Authorization", bearer(receiver.token())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.unreadCount").value(1))
                .andExpect(jsonPath("$.data.content[0].kind").value("FRIEND_REQUEST"))
                .andExpect(jsonPath("$.data.content[0].route").value("/friends/requests"))
                .andExpect(jsonPath("$.data.content[0].read").value(false))
                .andReturn();
        Number notificationId = JsonPath.read(
                feed.getResponse().getContentAsString(), "$.data.content[0].id");

        mockMvc.perform(patch("/api/notifications/{id}/read", notificationId.longValue())
                        .header("Authorization", bearer(sender.token())))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("RESOURCE_NOT_FOUND"));

        mockMvc.perform(patch("/api/notifications/{id}/read", notificationId.longValue())
                        .header("Authorization", bearer(receiver.token())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.updatedCount").value(1));

        mockMvc.perform(patch("/api/friends/requests/{id}", requestId.longValue())
                        .header("Authorization", bearer(receiver.token()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"action":"ACCEPT"}
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/notifications")
                        .header("Authorization", bearer(sender.token())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.unreadCount").value(1))
                .andExpect(jsonPath("$.data.content[0].kind").value("FRIEND_ACCEPTED"))
                .andExpect(jsonPath("$.data.content[0].route").value("/friends"));

        mockMvc.perform(patch("/api/notifications/read")
                        .header("Authorization", bearer(sender.token())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.updatedCount").value(1));
    }

    private Account account(String prefix) throws Exception {
        int sequence = SEQUENCE.incrementAndGet();
        String email = "notification-%d@lifequest.test".formatted(sequence);
        String nickname = "%s%d".formatted(prefix, sequence);
        MvcResult signup = mockMvc.perform(post("/api/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"password123","nickname":"%s"}
                                """.formatted(email, nickname)))
                .andExpect(status().isCreated())
                .andReturn();
        Number id = JsonPath.read(signup.getResponse().getContentAsString(), "$.data.userId");
        MvcResult login = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"password123"}
                                """.formatted(email)))
                .andExpect(status().isOk())
                .andReturn();
        String token = JsonPath.read(login.getResponse().getContentAsString(), "$.data.accessToken");
        return new Account(id.longValue(), token);
    }

    private String bearer(String token) {
        return "Bearer " + token;
    }

    private record Account(long id, String token) {
    }
}
