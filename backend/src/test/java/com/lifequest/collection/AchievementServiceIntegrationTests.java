package com.lifequest.collection;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import java.time.LocalDateTime;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class AchievementServiceIntegrationTests {

    private static final Long USER_ID = 992L;

    @Autowired
    private AchievementService achievementService;

    @Autowired
    private JdbcClient jdbcClient;

    @BeforeEach
    void createUser() {
        jdbcClient.sql("""
                INSERT INTO users
                    (id, email, nickname, role, total_exp, level, created_at, updated_at)
                VALUES
                    (:id, :email, :nickname, 'USER', 0, 1, :now, :now)
                """)
                .param("id", USER_ID)
                .param("email", "achievement-service@lifequest.test")
                .param("nickname", "업적테스터")
                .param("now", LocalDateTime.now())
                .update();
    }

    @Test
    void catalogContainsQuestBasedAchievementsAndMasksSecretOne() {
        AchievementResponse response = achievementService.catalog(USER_ID);

        assertThat(response.achievements()).hasSize(11);
        assertThat(response.achievements().get(0).name()).isEqualTo("모험의 발자국");
        assertThat(response.achievements())
                .filteredOn(AchievementResponse.Item::secret)
                .singleElement()
                .satisfies(item -> {
                    assertThat(item.name()).isEmpty();
                    assertThat(item.condition()).isNull();
                });
    }

    @Test
    void questCompletionAdvancesTotalAndSpecificQuestAchievements() {
        addCompletion(8101L, 8201L, 1L, LocalDate.of(2026, 8, 1));
        addCompletion(8102L, 8202L, 1L, LocalDate.of(2026, 8, 2));
        addCompletion(8103L, 8203L, 1L, LocalDate.of(2026, 8, 3));

        var unlocked = achievementService.evaluate(USER_ID);
        AchievementResponse mine = achievementService.mine(USER_ID);

        assertThat(unlocked).extracting(CollectionOutcome.Entry::name)
                .containsExactlyInAnyOrder("모험의 발자국 I", "물 한 잔의 습관 I");
        assertThat(item(mine, 1L)).satisfies(item -> {
            assertThat(item.currentValue()).isEqualTo(3);
            assertThat(item.requiredValue()).isEqualTo(10);
            assertThat(item.currentStep()).isEqualTo(1);
            assertThat(item.achieved()).isFalse();
        });
        assertThat(item(mine, 9L).currentStep()).isEqualTo(1);

        assertThat(achievementService.evaluate(USER_ID)).isEmpty();
    }

    @Test
    void legendaryQuestRevealsSecretAchievementAndGrantsTitle() {
        addCompletion(8301L, 8401L, 39L, LocalDate.of(2026, 8, 4));

        var unlocked = achievementService.evaluate(USER_ID);

        assertThat(unlocked)
                .filteredOn(CollectionOutcome.Entry::secret)
                .singleElement()
                .satisfies(entry -> {
                    assertThat(entry.name()).isEqualTo("전설의 시작");
                    assertThat(entry.reward()).isNotNull();
                    assertThat(entry.reward().code()).isEqualTo("ACHIEVEMENT_LEGEND");
                });
        assertThat(achievementService.catalog(USER_ID).achievements())
                .filteredOn(AchievementResponse.Item::secret)
                .singleElement()
                .extracting(AchievementResponse.Item::name)
                .isEqualTo("전설의 시작");
    }

    private AchievementResponse.Item item(AchievementResponse response, Long id) {
        return response.achievements().stream()
                .filter(item -> item.id().equals(id))
                .findFirst()
                .orElseThrow();
    }

    private void addCompletion(
            Long assignmentId, Long completionId, Long questId, LocalDate assignedDate) {
        LocalDateTime completedAt = assignedDate.atTime(12, 0);
        jdbcClient.sql("""
                INSERT INTO user_daily_quests
                    (id, user_id, quest_id, assigned_date, status, expires_at)
                VALUES
                    (:assignmentId, :userId, :questId, :assignedDate, 'COMPLETED', :expiresAt)
                """)
                .param("assignmentId", assignmentId)
                .param("userId", USER_ID)
                .param("questId", questId)
                .param("assignedDate", assignedDate)
                .param("expiresAt", completedAt.plusDays(1))
                .update();
        jdbcClient.sql("""
                INSERT INTO quest_completions
                    (id, user_daily_quest_id, user_id, quest_id, completed_at)
                VALUES
                    (:completionId, :assignmentId, :userId, :questId, :completedAt)
                """)
                .param("completionId", completionId)
                .param("assignmentId", assignmentId)
                .param("userId", USER_ID)
                .param("questId", questId)
                .param("completedAt", completedAt)
                .update();
    }
}
