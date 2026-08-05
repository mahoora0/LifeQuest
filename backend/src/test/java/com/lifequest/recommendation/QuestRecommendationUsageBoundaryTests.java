package com.lifequest.recommendation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class QuestRecommendationUsageBoundaryTests {

    private static final ZoneId SEOUL=ZoneId.of("Asia/Seoul");

    @Test
    void logicalDayChangesAtFourAmInSeoul() {
        assertUsageDate("2026-08-03T18:59:00Z",LocalDate.of(2026,8,3)); // 서울 03:59
        assertUsageDate("2026-08-03T19:00:00Z",LocalDate.of(2026,8,4)); // 서울 04:00
    }

    private void assertUsageDate(String instant,LocalDate expectedDate) {
        QuestRecommendationUsageRepository usages=mock(QuestRecommendationUsageRepository.class);
        UserRepository users=mock(UserRepository.class);
        LlmProperties properties=new LlmProperties();
        User user=mock(User.class);
        when(usages.findForUpdate(7L,expectedDate)).thenReturn(Optional.empty());
        when(users.findById(7L)).thenReturn(Optional.of(user));
        when(usages.saveAndFlush(any())).thenAnswer(invocation->invocation.getArgument(0));
        QuestRecommendationUsageService service=new QuestRecommendationUsageService(
                usages,users,properties,Clock.fixed(Instant.parse(instant),SEOUL));

        assertThat(service.consume(7L)).isEqualTo(9);
        verify(usages).findForUpdate(7L,expectedDate);
    }
}
