package com.lifequest.social;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.lifequest.quest.domain.CompletionType;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.domain.QuestCompletion;
import com.lifequest.quest.domain.QuestCreator;
import com.lifequest.quest.domain.QuestGrade;
import com.lifequest.quest.domain.UserDailyQuest;
import com.lifequest.quest.repository.QuestCompletionRepository;
import com.lifequest.quest.repository.QuestRepository;
import com.lifequest.quest.repository.UserDailyQuestRepository;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
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

        @Autowired
        private QuestRepository questRepository;

        @Autowired
        private UserDailyQuestRepository userDailyQuestRepository;

        @Autowired
        private QuestCompletionRepository questCompletionRepository;

        @Test
        void friendCodeIsCreatedAndFindsAnotherUser() throws Exception {
                TestUser owner = createUser("코드주인");
                TestUser finder = createUser("코드검색");

                MvcResult codeResult = mockMvc.perform(get("/api/users/me/friend-code")
                                .header("Authorization", bearer(owner.token())))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.data.friendCode").value(org.hamcrest.Matchers.matchesPattern("LQ-[0-9A-F]{8}")))
                                .andReturn();
                String code = JsonPath.read(codeResult.getResponse().getContentAsString(), "$.data.friendCode");

                mockMvc.perform(get("/api/users/search")
                                .header("Authorization", bearer(finder.token()))
                                .queryParam("query", code))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.data.content[0].userId").value(owner.id()))
                                .andExpect(jsonPath("$.data.content[0].nickname").value(owner.nickname()));
        }

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

                mockMvc.perform(get("/api/friends/requests/sent")
                                .header("Authorization", bearer(sender.token()))
                                .queryParam("page", "0")
                                .queryParam("size", "20"))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.data.content.length()").value(1))
                                .andExpect(jsonPath("$.data.content[0].requestId").value(requestId))
                                .andExpect(jsonPath("$.data.content[0].receiverId").value(receiver.id()))
                                .andExpect(jsonPath("$.data.content[0].receiverNickname")
                                                .value(receiver.nickname()))
                                .andExpect(jsonPath("$.data.content[0].status").value("PENDING"));
        }

        @Test
        void senderCanCancelPendingFriendRequest() throws Exception {
                TestUser sender = createUser("취소발신");
                TestUser receiver = createUser("취소수신");
                long requestId = sendRequest(sender, receiver.id());

                mockMvc.perform(delete("/api/friends/requests/{requestId}", requestId)
                                .header("Authorization", bearer(sender.token())))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.data.requestId").value(requestId))
                                .andExpect(jsonPath("$.data.status").value("CANCELLED"));

                mockMvc.perform(get("/api/friends/requests/sent")
                                .header("Authorization", bearer(sender.token())))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.data.content.length()").value(0));
                mockMvc.perform(get("/api/friends/requests")
                                .header("Authorization", bearer(receiver.token())))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.data.content.length()").value(0));
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

        // 친구 목록 조회 테스트
        @Test
        void acceptedFriendsAppearInOwnPaginatedListOnly() throws Exception {
                TestUser owner = createUser("목록사용자");
                TestUser firstFriend = createUser("첫친구");
                TestUser secondFriend = createUser("둘째친구");
                TestUser outsider = createUser("목록외부인");

                acceptRequest(owner, sendRequest(firstFriend, owner.id()));
                acceptRequest(owner, sendRequest(secondFriend, owner.id()));

                mockMvc.perform(get("/api/friends")
                                .header("Authorization", bearer(owner.token()))
                                .queryParam("page", "0")
                                .queryParam("size", "1"))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.data.content.length()").value(1))
                                .andExpect(jsonPath("$.data.page").value(0))
                                .andExpect(jsonPath("$.data.size").value(1))
                                .andExpect(jsonPath("$.data.totalElements").value(2))
                                .andExpect(jsonPath("$.data.totalPages").value(2))
                                .andExpect(jsonPath("$.data.content[0].userId")
                                                .value(secondFriend.id()))
                                .andExpect(jsonPath("$.data.content[0].nickname")
                                                .value(secondFriend.nickname()))
                                .andExpect(jsonPath("$.data.content[0].level").value(1))
                                .andExpect(jsonPath("$.data.content[0].totalExp").value(0))
                                .andExpect(jsonPath("$.data.content[0].friendsSince").isNotEmpty());

                mockMvc.perform(get("/api/friends")
                                .header("Authorization", bearer(outsider.token())))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.data.content.length()").value(0))
                                .andExpect(jsonPath("$.data.totalElements").value(0));
        }

        // 친구 삭제 테스트
        @Test
        void deletingFriendRemovesBothDirectionsAndCannotBeRepeated() throws Exception {
                TestUser first = createUser("삭제사용자");
                TestUser second = createUser("삭제친구");
                acceptRequest(second, sendRequest(first, second.id()));

                mockMvc.perform(delete("/api/friends/{friendId}", second.id())
                                .header("Authorization", bearer(first.token())))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.data.deleted").value(true));

                assertFalse(friendshipRepository.existsByUserIdAndFriendId(
                                first.id(), second.id()));
                assertFalse(friendshipRepository.existsByUserIdAndFriendId(
                                second.id(), first.id()));

                mockMvc.perform(delete("/api/friends/{friendId}", second.id())
                                .header("Authorization", bearer(first.token())))
                                .andExpect(status().isNotFound())
                                .andExpect(jsonPath("$.error.code").value("FRIENDSHIP_NOT_FOUND"));
        }

        // 친구 공개 프로필과 활동 요약 조회 테스트
        @Test
        void friendProfileComparesPublicActivityWithoutExposingPrivateData() throws Exception {
                TestUser owner = createUser("프로필사용자");
                TestUser friend = createUser("프로필친구");
                TestUser outsider = createUser("프로필외부인");
                acceptRequest(friend, sendRequest(owner, friend.id()));

                completeQuest(friend.id(), "같은 공원", 0);
                completeQuest(friend.id(), "같은 공원", 1);
                completeQuest(friend.id(), null, 2);

                mockMvc.perform(get("/api/friends/{friendId}/profile", friend.id())
                                .header("Authorization", bearer(owner.token())))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.data.userId").value(friend.id()))
                                .andExpect(jsonPath("$.data.nickname").value(friend.nickname()))
                                .andExpect(jsonPath("$.data.me.level").value(1))
                                .andExpect(jsonPath("$.data.me.completedQuestCount").value(0))
                                .andExpect(jsonPath("$.data.me.visitedPlaceCount").value(0))
                                .andExpect(jsonPath("$.data.friend.level").value(1))
                                .andExpect(jsonPath("$.data.friend.completedQuestCount").value(3))
                                .andExpect(jsonPath("$.data.friend.visitedPlaceCount").value(1))
                                .andExpect(jsonPath("$.data.email").doesNotExist())
                                .andExpect(jsonPath("$.data.friend.email").doesNotExist())
                                .andExpect(jsonPath("$.data.friend.verifiedLatitude").doesNotExist());

                mockMvc.perform(get("/api/friends/{friendId}/profile", friend.id())
                                .header("Authorization", bearer(outsider.token())))
                                .andExpect(status().isNotFound())
                                .andExpect(jsonPath("$.error.code").value("FRIENDSHIP_NOT_FOUND"));
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

        // 친구 요청 수락 헬퍼
        private void acceptRequest(TestUser receiver, long requestId)
                        throws Exception {
                mockMvc.perform(patch("/api/friends/requests/{requestId}", requestId)
                                .header("Authorization", bearer(receiver.token()))
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                                {"action":"ACCEPT"}
                                                """))
                                .andExpect(status().isOk());
        }

        // 공개 활동 집계용 완료 기록 생성 헬퍼
        private void completeQuest(long userId, String placeName, int dayOffset) {
                boolean locationBased = placeName != null;
                Quest quest = questRepository.save(new Quest(
                                "프로필 집계 퀘스트 " + SEQUENCE.incrementAndGet(),
                                "친구 프로필 테스트",
                                QuestGrade.NORMAL,
                                QuestCadence.DAILY,
                                locationBased ? CompletionType.LOCATION : CompletionType.SELF_REPORT,
                                10,
                                placeName,
                                locationBased ? new BigDecimal("37.5665000") : null,
                                locationBased ? new BigDecimal("126.9780000") : null,
                                locationBased ? 100 : null,
                                null,
                                QuestCreator.ADMIN,
                                true));
                LocalDate assignedDate = LocalDate.now().plusDays(dayOffset);
                UserDailyQuest assignment = userDailyQuestRepository.save(new UserDailyQuest(
                                userId,
                                quest.getId(),
                                assignedDate,
                                assignedDate.plusDays(1).atStartOfDay()));
                assignment.markCompleted();
                questCompletionRepository.save(new QuestCompletion(
                                assignment,
                                null,
                                null,
                                null,
                                null,
                                LocalDateTime.now().plusDays(dayOffset)));
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
