package com.lifequest.recommendation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.lifequest.auth.AuthService;
import com.lifequest.auth.dto.SignupRequest;
import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.user.UserRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class QuestRecommendationUsageIntegrationTests {
    @Autowired AuthService auth;
    @Autowired UserRepository users;
    @Autowired QuestRecommendationUsageService usage;

    @Test
    void eleventhRequestIsRejected() {
        Long id=user("usageSequential");
        for(int remaining=9;remaining>=0;remaining--) assertThat(usage.consume(id)).isEqualTo(remaining);
        assertThatThrownBy(()->usage.consume(id)).isInstanceOfSatisfying(
                BusinessException.class,e->assertThat(e.errorCode()).isEqualTo(ErrorCode.LLM_DAILY_LIMIT_EXCEEDED));
    }

    @Test
    void concurrentConsumptionNeverExceedsTheConfiguredDailyLimit() throws Exception {
        Long id=user("usageConcurrent");
        assertThat(usage.consume(id)).isEqualTo(9); // 행을 먼저 만든 뒤 같은 행 잠금을 경쟁시킨다.
        int workers=12;
        CountDownLatch ready=new CountDownLatch(workers);
        CountDownLatch start=new CountDownLatch(1);
        ExecutorService executor=Executors.newFixedThreadPool(workers);
        try {
            List<Future<Boolean>> results=new ArrayList<>();
            for(int i=0;i<workers;i++) results.add(executor.submit(()->consume(id,ready,start)));
            ready.await();
            start.countDown();
            int successes=0;
            for(Future<Boolean> result:results) if(result.get()) successes++;
            assertThat(successes).isEqualTo(9);
            assertThat(workers-successes).isEqualTo(3);
            assertThatThrownBy(()->usage.consume(id)).isInstanceOfSatisfying(
                    BusinessException.class,e->assertThat(e.errorCode()).isEqualTo(ErrorCode.LLM_DAILY_LIMIT_EXCEEDED));
        } finally {
            executor.shutdownNow();
        }
    }

    private boolean consume(Long id,CountDownLatch ready,CountDownLatch start) throws InterruptedException {
        ready.countDown();
        start.await();
        try {
            usage.consume(id);
            return true;
        } catch(BusinessException exception) {
            assertThat(exception.errorCode()).isEqualTo(ErrorCode.LLM_DAILY_LIMIT_EXCEEDED);
            return false;
        }
    }

    private Long user(String prefix) {
        String suffix=UUID.randomUUID().toString().substring(0,8);
        String email=prefix+suffix+"@lifequest.test";
        auth.signup(new SignupRequest(email,"password123",prefix+suffix));
        return users.findByEmailIgnoreCase(email).orElseThrow().getId();
    }
}
