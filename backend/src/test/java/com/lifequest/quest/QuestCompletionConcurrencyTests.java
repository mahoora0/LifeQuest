package com.lifequest.quest;

import static org.assertj.core.api.Assertions.assertThat;

import com.jayway.jsonpath.JsonPath;
import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.quest.domain.CompletionType;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.domain.QuestCreator;
import com.lifequest.quest.domain.QuestGrade;
import com.lifequest.quest.domain.UserDailyQuest;
import com.lifequest.quest.dto.QuestCompletionRequest;
import com.lifequest.quest.repository.QuestRepository;
import com.lifequest.quest.repository.UserDailyQuestRepository;
import com.lifequest.quest.service.QuestCompletionService;
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

/**
 * [[lock-poisoned-by-earlier-plain-read]] 수정 검증 —
 * QuestCompletionServiceImpl:95의 락 없는 User 조회를 중복 완료 분기 안으로
 * 옮긴 뒤, 같은 유저가 서로 다른 두 퀘스트를 동시에 완료해도 EXP가
 * 유실되지 않는지 실제 {@code complete()} 경로로 검증한다.
 */
@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
class QuestCompletionConcurrencyTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private QuestRepository questRepository;

    @Autowired
    private UserDailyQuestRepository userDailyQuestRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private QuestCompletionService questCompletionService;

    @Test
    void 같은_유저의_동시_완료_두_건이_EXP를_모두_반영한다() throws Exception {
        String email = "concurrent-complete@lifequest.test";
        signUpAndGetAccessToken(email, "동시완료모험가");
        long userId = userRepository.findByEmailIgnoreCase(email)
            .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND))
            .getId();

        long dailyQuestId1 = assignSelfReportQuest(email, LocalDateTime.now().plusDays(1));
        long dailyQuestId2 = assignSelfReportQuest(email, LocalDateTime.now().plusDays(1));

        int expReward = questRepository.findById(
                userDailyQuestRepository.findById(dailyQuestId1).orElseThrow().getQuestId())
            .orElseThrow()
            .getExpReward();

        int before = userRepository.findById(userId).orElseThrow().getTotalExp();

        // 두 완료가 실제로 겹치도록 동시 시작점을 강제한다.
        CountDownLatch ready = new CountDownLatch(2);
        Callable<Void> completeFirst = () -> {
            ready.countDown();
            ready.await(5, TimeUnit.SECONDS);
            questCompletionService.complete(userId, dailyQuestId1, QuestCompletionRequest.empty());
            return null;
        };
        Callable<Void> completeSecond = () -> {
            ready.countDown();
            ready.await(5, TimeUnit.SECONDS);
            questCompletionService.complete(userId, dailyQuestId2, QuestCompletionRequest.empty());
            return null;
        };

        ExecutorService pool = Executors.newFixedThreadPool(2);
        List<Future<Void>> futures = pool.invokeAll(List.of(completeFirst, completeSecond));
        pool.shutdown();
        assertThat(pool.awaitTermination(10, TimeUnit.SECONDS)).isTrue();
        for (Future<Void> future : futures) {
            future.get();
        }

        int after = userRepository.findById(userId).orElseThrow().getTotalExp();
        assertThat(after)
            .as("두 완료(각 %d EXP)가 모두 반영돼야 한다", expReward)
            .isEqualTo(before + expReward * 2);
    }

    private long assignSelfReportQuest(String email, LocalDateTime expiresAt) {
        User user = userRepository.findByEmailIgnoreCase(email)
            .orElseThrow(() -> new IllegalStateException("픽스처 대상 사용자가 없다: " + email));

        Quest quest = questRepository.save(new Quest(
            "동시성 테스트용 보고 퀘스트", "동시성 테스트 픽스처", QuestGrade.NORMAL, QuestCadence.DAILY,
            CompletionType.SELF_REPORT, 50,
            null, null, null, null, null,
            QuestCreator.SYSTEM, true));

        UserDailyQuest assignment = userDailyQuestRepository.save(
            new UserDailyQuest(user.getId(), quest.getId(), LocalDate.now(), expiresAt));

        return assignment.getId();
    }

    private String signUpAndGetAccessToken(String email, String nickname) throws Exception {
        mockMvc.perform(post("/api/auth/signup")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                      "email": "%s",
                      "password": "password123",
                      "nickname": "%s"
                    }
                    """.formatted(email, nickname)))
            .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.status().isCreated());

        MvcResult login = mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                      "email": "%s",
                      "password": "password123"
                    }
                    """.formatted(email)))
            .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.status().isOk())
            .andReturn();

        return JsonPath.read(login.getResponse().getContentAsString(), "$.data.accessToken");
    }
}
