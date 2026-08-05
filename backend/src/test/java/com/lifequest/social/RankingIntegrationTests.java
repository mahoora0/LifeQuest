package com.lifequest.social;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
import java.util.List;
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
class RankingIntegrationTests {

    private static final AtomicInteger SEQUENCE = new AtomicInteger();

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private FriendshipRepository friendshipRepository;

    @Test
    void globalRankingOrdersByTotalExpThenUserIdAndMarksCurrentUser() throws Exception {
        TestUser leader = createUser("전체선두");
        TestUser firstTie = createUser("전체동점앞");
        TestUser secondTie = createUser("전체동점뒤");
        addExp(leader.id(), 1_000_000_000);
        addExp(firstTie.id(), 900_000_000);
        addExp(secondTie.id(), 900_000_000);

        mockMvc.perform(get("/api/rankings/global")
                        .header("Authorization", bearer(firstTie.token()))
                        .queryParam("page", "0")
                        .queryParam("size", "3"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content.length()").value(3))
                .andExpect(jsonPath("$.data.content[0].rank").value(1))
                .andExpect(jsonPath("$.data.content[0].userId").value(leader.id()))
                .andExpect(jsonPath("$.data.content[0].totalExp").value(1_000_000_000))
                .andExpect(jsonPath("$.data.content[1].rank").value(2))
                .andExpect(jsonPath("$.data.content[1].userId").value(firstTie.id()))
                .andExpect(jsonPath("$.data.content[1].isMe").value(true))
                .andExpect(jsonPath("$.data.content[2].rank").value(3))
                .andExpect(jsonPath("$.data.content[2].userId").value(secondTie.id()))
                .andExpect(jsonPath("$.data.page").value(0))
                .andExpect(jsonPath("$.data.size").value(3));

        mockMvc.perform(get("/api/rankings/global")
                        .header("Authorization", bearer(firstTie.token()))
                        .queryParam("page", "1")
                        .queryParam("size", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content[0].rank").value(3))
                .andExpect(jsonPath("$.data.content[0].userId").value(secondTie.id()));
    }

    @Test
    void friendRankingContainsOnlyCurrentUserAndFriends() throws Exception {
        TestUser owner = createUser("친구랭킹본인");
        TestUser friend = createUser("친구랭킹친구");
        TestUser outsider = createUser("친구랭킹외부");
        addExp(owner.id(), 300_000);
        addExp(friend.id(), 500_000);
        addExp(outsider.id(), 700_000);
        makeFriends(owner.id(), friend.id());

        mockMvc.perform(get("/api/rankings/friends")
                        .header("Authorization", bearer(owner.token()))
                        .queryParam("page", "0")
                        .queryParam("size", "20"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content.length()").value(2))
                .andExpect(jsonPath("$.data.totalElements").value(2))
                .andExpect(jsonPath("$.data.content[0].userId").value(friend.id()))
                .andExpect(jsonPath("$.data.content[0].rank").value(1))
                .andExpect(jsonPath("$.data.content[0].isMe").value(false))
                .andExpect(jsonPath("$.data.content[1].userId").value(owner.id()))
                .andExpect(jsonPath("$.data.content[1].rank").value(2))
                .andExpect(jsonPath("$.data.content[1].isMe").value(true));
    }

    @Test
    void levelRankingOrdersByLevelThenTotalExpAndSupportsFriendScope() throws Exception {
        TestUser owner = createUser("레벨본인");
        TestUser higherLevel = createUser("레벨선두");
        TestUser sameLevelLowerExp = createUser("레벨동점");
        TestUser outsider = createUser("레벨외부인");
        setGrowth(owner.id(), 700, 8);
        setGrowth(higherLevel.id(), 600, 9);
        setGrowth(sameLevelLowerExp.id(), 500, 8);
        setGrowth(outsider.id(), 10_000, 99);
        makeFriends(owner.id(), higherLevel.id());
        makeFriends(owner.id(), sameLevelLowerExp.id());

        mockMvc.perform(get("/api/rankings/friends")
                        .header("Authorization", bearer(owner.token()))
                        .queryParam("type", "LEVEL"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.type").value("LEVEL"))
                .andExpect(jsonPath("$.data.content.length()").value(3))
                .andExpect(jsonPath("$.data.content[0].userId").value(higherLevel.id()))
                .andExpect(jsonPath("$.data.content[0].level").value(9))
                .andExpect(jsonPath("$.data.content[1].userId").value(owner.id()))
                .andExpect(jsonPath("$.data.content[2].userId").value(sameLevelLowerExp.id()));
    }

    @Test
    void rankingRejectsInvalidPagination() throws Exception {
        TestUser user = createUser("랭킹검증");

        mockMvc.perform(get("/api/rankings/global")
                        .header("Authorization", bearer(user.token()))
                        .queryParam("page", "-1"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_FAILED"));

        mockMvc.perform(get("/api/rankings/global")
                        .header("Authorization", bearer(user.token()))
                        .queryParam("type", "WEEKLY"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_FAILED"));

        mockMvc.perform(get("/api/rankings/friends")
                        .header("Authorization", bearer(user.token()))
                        .queryParam("size", "101"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_FAILED"));
    }

    private void addExp(long userId, int amount) {
        User user = userRepository.findById(userId).orElseThrow();
        user.addExp(amount, 100);
        userRepository.save(user);
    }

    private void setGrowth(long userId, int totalExp, int level) {
        User user = userRepository.findById(userId).orElseThrow();
        user.addExp(totalExp, level);
        userRepository.save(user);
    }

    private void makeFriends(long firstId, long secondId) {
        User first = userRepository.findById(firstId).orElseThrow();
        User second = userRepository.findById(secondId).orElseThrow();
        friendshipRepository.saveAll(List.of(
                new Friendship(first, second),
                new Friendship(second, first)));
    }

    private TestUser createUser(String nicknamePrefix) throws Exception {
        int sequence = SEQUENCE.incrementAndGet();
        String email = "ranking-%d@lifequest.test".formatted(sequence);
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
        return new TestUser(userId.longValue(), token);
    }

    private String bearer(String token) {
        return "Bearer " + token;
    }

    private record TestUser(long id, String token) {
    }
}
