package com.lifequest.integration;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.lifequest.quest.domain.CompletionType;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.domain.QuestCategory;
import com.lifequest.quest.domain.QuestCreator;
import com.lifequest.quest.domain.QuestGrade;
import com.lifequest.quest.domain.UserDailyQuest;
import com.lifequest.quest.repository.QuestRepository;
import com.lifequest.quest.repository.UserDailyQuestRepository;
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
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

@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
class Member4DataFlowIntegrationTests {
    private static final AtomicInteger SEQUENCE = new AtomicInteger();

    @Autowired MockMvc mockMvc;
    @Autowired UserRepository userRepository;
    @Autowired QuestRepository questRepository;
    @Autowired UserDailyQuestRepository userDailyQuestRepository;

    @Test
    void questCompletionUpdatesGrowthRewardsAndFriendRankingTogether() throws Exception {
        Account adventurer = account("통합모험가");
        Account friend = account("통합친구");

        Number requestId = sendRequest(adventurer, friend);
        mockMvc.perform(patch("/api/friends/requests/{id}", requestId.longValue())
                        .header("Authorization", bearer(friend.token()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"action":"ACCEPT"}
                                """))
                .andExpect(status().isOk());

        long assignmentId = assignQuest(adventurer.id());
        mockMvc.perform(post("/api/daily-quests/{id}/complete", assignmentId)
                        .header("Authorization", bearer(adventurer.token()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.growth.expGained").value(150))
                .andExpect(jsonPath("$.data.growth.totalExp").value(150))
                .andExpect(jsonPath("$.data.growth.currentLevel").value(2))
                .andExpect(jsonPath("$.data.growth.levelUp").value(true))
                .andExpect(jsonPath("$.data.growth.rewards[0].type").value("TITLE"))
                .andExpect(jsonPath("$.data.growth.rewards[0].code")
                        .value("NEIGHBORHOOD_EXPLORER"));

        mockMvc.perform(get("/api/users/me/level")
                        .header("Authorization", bearer(adventurer.token())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.level").value(2))
                .andExpect(jsonPath("$.data.totalExp").value(150));

        mockMvc.perform(get("/api/users/me/quests/history")
                        .header("Authorization", bearer(adventurer.token()))
                        .queryParam("page", "0")
                        .queryParam("size", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalElements").value(1))
                .andExpect(jsonPath("$.data.content.length()").value(1))
                .andExpect(jsonPath("$.data.content[0].expReward").value(150))
                .andExpect(jsonPath("$.data.content[0].completedAt").isNotEmpty());

        mockMvc.perform(get("/api/users/me/rewards")
                        .header("Authorization", bearer(adventurer.token())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.titles[?(@.name == '동네 탐험가')]").exists());

        mockMvc.perform(get("/api/rankings/friends")
                        .header("Authorization", bearer(adventurer.token()))
                        .queryParam("type", "EXP"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content.length()").value(2))
                .andExpect(jsonPath("$.data.content[0].userId").value(adventurer.id()))
                .andExpect(jsonPath("$.data.content[0].totalExp").value(150))
                .andExpect(jsonPath("$.data.content[0].isMe").value(true))
                .andExpect(jsonPath("$.data.content[1].userId").value(friend.id()));
    }

    private Number sendRequest(Account sender, Account receiver) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/friends/requests")
                        .header("Authorization", bearer(sender.token()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"receiverId":%d}
                                """.formatted(receiver.id())))
                .andExpect(status().isCreated())
                .andReturn();
        return JsonPath.read(result.getResponse().getContentAsString(), "$.data.requestId");
    }

    private long assignQuest(long userId) {
        Quest quest = questRepository.save(new Quest(
                "통합 검증 퀘스트", "도메인 연결 검증", QuestCategory.DAILY_HABIT,
                QuestGrade.LEGENDARY,
                QuestCadence.DAILY, CompletionType.SELF_REPORT, 150,
                null, null, null, null, null, QuestCreator.SYSTEM, true));
        UserDailyQuest assignment = userDailyQuestRepository.save(new UserDailyQuest(
                userId, quest.getId(), LocalDate.now(), LocalDateTime.now().plusDays(1)));
        return assignment.getId();
    }

    private Account account(String prefix) throws Exception {
        int sequence = SEQUENCE.incrementAndGet();
        String email = "member4-integration-%d@lifequest.test".formatted(sequence);
        String nickname = "%s%d".formatted(prefix, sequence);
        MvcResult signup = mockMvc.perform(post("/api/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"password123","nickname":"%s"}
                                """.formatted(email, nickname)))
                .andExpect(status().isCreated())
                .andReturn();
        Number id = JsonPath.read(signup.getResponse().getContentAsString(), "$.data.userId");
        User user = userRepository.findById(id.longValue()).orElseThrow();
        org.assertj.core.api.Assertions.assertThat(user.getTotalExp()).isZero();

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
