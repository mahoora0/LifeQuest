package com.lifequest.social;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
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

// 친구 요청 API 통합 테스트
@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
class FriendFlowIntegrationTests {

        private static final AtomicInteger SEQUENCE = new AtomicInteger();

        @Autowired
        private MockMvc mockMvc;

        @Autowired
        private FriendRequestRepository friendRequestRepository;

        @Autowired
        private FriendshipRepository friendshipRepository;

        // 요청 전송 및 목록 테스트
        @Test
        void sentRequestAppearsInReceiversPendingRequestList() throws Exception {
                TestUser sender = createUser("요청자");
                TestUser receiver = createUser("수신자");

                long requestId = sendRequest(sender, receiver.id());

                mockMvc.perform(get("/api/friends/requests")
                                .header("Authorization", bearer(receiver.token()))
                                .queryParam("page", "0")
                                .queryParam("size", "20"))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.success").value(true))
                                .andExpect(jsonPath("$.data.content.length()").value(1))
                                .andExpect(jsonPath("$.data.content[0].requestId").value(requestId))
                                .andExpect(jsonPath("$.data.content[0].senderId").value(sender.id()))
                                .andExpect(jsonPath("$.data.content[0].senderNickname")
                                                .value(sender.nickname()))
                                .andExpect(jsonPath("$.data.content[0].status").value("PENDING"))
                                .andExpect(jsonPath("$.data.page").value(0))
                                .andExpect(jsonPath("$.data.totalElements").value(1));
        }

        // 요청 수락 테스트
        @Test
        void acceptingRequestCreatesBothFriendshipDirectionsAndCannotBeRepeated()
                        throws Exception {
                TestUser sender = createUser("수락요청자");
                TestUser receiver = createUser("수락수신자");
                long requestId = sendRequest(sender, receiver.id());

                mockMvc.perform(patch("/api/friends/requests/{requestId}", requestId)
                                .header("Authorization", bearer(receiver.token()))
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                                {"action":"ACCEPT"}
                                                """))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.data.requestId").value(requestId))
                                .andExpect(jsonPath("$.data.status").value("ACCEPTED"))
                                .andExpect(jsonPath("$.data.respondedAt").isNotEmpty());

                assertTrue(friendshipRepository.existsByUserIdAndFriendId(
                                sender.id(), receiver.id()));
                assertTrue(friendshipRepository.existsByUserIdAndFriendId(
                                receiver.id(), sender.id()));

                mockMvc.perform(patch("/api/friends/requests/{requestId}", requestId)
                                .header("Authorization", bearer(receiver.token()))
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                                {"action":"ACCEPT"}
                                                """))
                                .andExpect(status().isConflict())
                                .andExpect(jsonPath("$.error.code").value("CONFLICT"));
        }

        // 요청 거절 테스트
        @Test
        void rejectingRequestChangesStatusWithoutCreatingFriendship() throws Exception {
                TestUser sender = createUser("거절요청자");
                TestUser receiver = createUser("거절수신자");
                long requestId = sendRequest(sender, receiver.id());

                mockMvc.perform(patch("/api/friends/requests/{requestId}", requestId)
                                .header("Authorization", bearer(receiver.token()))
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                                {"action":"REJECT"}
                                                """))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.data.status").value("REJECTED"))
                                .andExpect(jsonPath("$.data.respondedAt").isNotEmpty());

                FriendRequest rejected = friendRequestRepository.findById(requestId).orElseThrow();
                assertTrue(rejected.getStatus() == FriendRequestStatus.REJECTED);
                assertFalse(friendshipRepository.existsByUserIdAndFriendId(
                                sender.id(), receiver.id()));
                assertFalse(friendshipRepository.existsByUserIdAndFriendId(
                                receiver.id(), sender.id()));
        }

        // 요청 규칙 테스트
        @Test
        void requestRulesRejectSelfDuplicatesReverseDuplicatesAndUnauthorizedResponse()
                        throws Exception {
                TestUser sender = createUser("규칙요청자");
                TestUser receiver = createUser("규칙수신자");
                TestUser outsider = createUser("제삼자");

                mockMvc.perform(post("/api/friends/requests")
                                .header("Authorization", bearer(sender.token()))
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                                {"receiverId":%d}
                                                """.formatted(sender.id())))
                                .andExpect(status().isBadRequest())
                                .andExpect(jsonPath("$.error.code")
                                                .value("SELF_FRIEND_REQUEST_NOT_ALLOWED"));

                long requestId = sendRequest(sender, receiver.id());

                mockMvc.perform(post("/api/friends/requests")
                                .header("Authorization", bearer(sender.token()))
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                                {"receiverId":%d}
                                                """.formatted(receiver.id())))
                                .andExpect(status().isConflict())
                                .andExpect(jsonPath("$.error.code").value("DUPLICATE_FRIEND_REQUEST"));

                mockMvc.perform(post("/api/friends/requests")
                                .header("Authorization", bearer(receiver.token()))
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                                {"receiverId":%d}
                                                """.formatted(sender.id())))
                                .andExpect(status().isConflict())
                                .andExpect(jsonPath("$.error.code").value("DUPLICATE_FRIEND_REQUEST"));

                mockMvc.perform(patch("/api/friends/requests/{requestId}", requestId)
                                .header("Authorization", bearer(outsider.token()))
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                                {"action":"ACCEPT"}
                                                """))
                                .andExpect(status().isForbidden())
                                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));
        }

        // 친구 요청 전송 헬퍼
        private long sendRequest(TestUser sender, long receiverId) throws Exception {
                MvcResult result = mockMvc.perform(post("/api/friends/requests")
                                .header("Authorization", bearer(sender.token()))
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                                {"receiverId":%d}
                                                """.formatted(receiverId)))
                                .andExpect(status().isCreated())
                                .andExpect(jsonPath("$.data.status").value("PENDING"))
                                .andExpect(jsonPath("$.data.createdAt").isNotEmpty())
                                .andReturn();
                Number requestId = JsonPath.read(
                                result.getResponse().getContentAsString(),
                                "$.data.requestId");
                return requestId.longValue();
        }

        // 테스트용 사용자 생성 헬퍼
        private TestUser createUser(String nicknamePrefix) throws Exception {
                int sequence = SEQUENCE.incrementAndGet();
                String email = "friend-flow-%d@lifequest.test".formatted(sequence);
                String nickname = "%s%d".formatted(nicknamePrefix, sequence);

                MvcResult signup = mockMvc.perform(post("/api/auth/signup")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                                {
                                                  "email":"%s",
                                                  "password":"password123",
                                                  "nickname":"%s"
                                                }
                                                """.formatted(email, nickname)))
                                .andExpect(status().isCreated())
                                .andReturn();
                Number userId = JsonPath.read(
                                signup.getResponse().getContentAsString(),
                                "$.data.userId");

                MvcResult login = mockMvc.perform(post("/api/auth/login")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                                {"email":"%s","password":"password123"}
                                                """.formatted(email)))
                                .andExpect(status().isOk())
                                .andReturn();
                String token = JsonPath.read(
                                login.getResponse().getContentAsString(),
                                "$.data.accessToken");

                return new TestUser(userId.longValue(), token, nickname);
        }

        // Bearer 토큰 생성 헬퍼
        private String bearer(String token) {
                return "Bearer " + token;
        }

        // 테스트용 사용자 레코드
        private record TestUser(long id, String token, String nickname) {
        }
}
