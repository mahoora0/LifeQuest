package com.lifequest.collection;

import static org.assertj.core.api.Assertions.assertThat;

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
class LifedexServiceIntegrationTests {

    private static final Long USER_ID = 991L;

    @Autowired
    private LifedexService lifedexService;

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
                .param("email", "lifedex-service@lifequest.test")
                .param("nickname", "도감서비스모험가")
                .param("now", LocalDateTime.now())
                .update();
    }

    @Test
    void locationQuestCollectsMappedItemOnlyOnce() {
        CollectionOutcome first = lifedexService.evaluateOnQuestCompletion(
                USER_ID, 21L, 21L, 7001L);
        CollectionOutcome duplicate = lifedexService.evaluateOnQuestCompletion(
                USER_ID, 21L, 21L, 7002L);

        assertThat(first.newLifedexItems()).singleElement().satisfies(item -> {
            assertThat(item.id()).isEqualTo(21L);
            assertThat(item.name()).isEqualTo("청계천");
            assertThat(item.secret()).isFalse();
        });
        assertThat(duplicate.newLifedexItems()).isEmpty();
        assertThat(lifedexService.categories(USER_ID).categories())
                .filteredOn(category -> category.name().equals("산 · 하천"))
                .singleElement()
                .extracting(LifedexCategoryResponse.Category::ownedCount)
                .isEqualTo(1L);
    }

    @Test
    void questWithoutMappedItemDoesNotChangeCollection() {
        CollectionOutcome outcome = lifedexService.evaluateOnQuestCompletion(
                USER_ID, 1L, null, 7003L);

        assertThat(outcome.newLifedexItems()).isEmpty();
        assertThat(lifedexService.items(USER_ID, null).items())
                .hasSize(15)
                .noneMatch(LifedexResponse.Item::owned);
    }
}
