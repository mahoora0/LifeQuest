package com.lifequest.growth;

import static org.assertj.core.api.Assertions.assertThat;

import com.lifequest.auth.AuthService;
import com.lifequest.auth.dto.SignupRequest;
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * QuestCompletionServiceImpl.complete()는 grantExp를 호출하기 전에
 * userRepository.findById(락 없음)를 먼저 실행한다. 같은 트랜잭션 안에서
 * 이 평범한 조회가 먼저 영속성 컨텍스트에 캐싱되면, 뒤이은 grantExp의
 * findByIdForUpdate가 락은 얻어도 엔티티를 재적재하지 않는다는 가설을
 * 재현한다 — mysql-lock-lab.sh의 "락 앞 SELECT가 락을 무력화한다"와
 * 같은 인과 구조를 ORM 계층에서 검증한다.
 */
@SpringBootTest
@ActiveProfiles("test")
class GrowthServiceConcurrentLockTests {

    @Autowired
    private AuthService authService;

    @Autowired
    private GrowthService growthService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @Test
    @Disabled(
        "진단용 — QuestCompletionServiceImpl:95의 안티패턴(같은 트랜잭션 내 락 없는 선행 조회)을 "
            + "이 테스트 안에서 직접 재현한다. 그 파일을 고쳐도 이 테스트 자체는 안티패턴을 다시 "
            + "실행하므로 항상 실패한다 — CI를 막지 않도록 비활성화하되, 인과 증명 기록으로 남긴다. "
            + "실제 회귀 가드는 QuestCompletionConcurrencyTests(실제 complete() 경로)가 맡는다.")
    void plainReadBeforeGrantExpLosesConcurrentExp() throws Exception {
        authService.signup(new SignupRequest(
                "concurrency@lifequest.test", "password123", "동시성테스터"));
        Long userId = userRepository.findByEmailIgnoreCase("concurrency@lifequest.test")
                .orElseThrow()
                .getId();

        TransactionTemplate txTemplate = new TransactionTemplate(transactionManager);
        txTemplate.setIsolationLevel(TransactionDefinition.ISOLATION_READ_COMMITTED);

        // 두 트랜잭션이 각자 평범한 조회를 마칠 때까지 서로를 기다리게 해
        // "둘 다 락 걸기 전에 캐싱부터 끝낸" 상태를 강제로 만든다.
        CountDownLatch bothPlainReadsDone = new CountDownLatch(2);

        Callable<Void> txA = () -> {
            txTemplate.execute(status -> {
                userRepository.findById(userId); // QuestCompletionServiceImpl:95와 동일한 선행 조회
                bothPlainReadsDone.countDown();
                awaitQuietly(bothPlainReadsDone);
                growthService.grantExp(userId, "TXA", 1001L, 30);
                return null;
            });
            return null;
        };

        Callable<Void> txB = () -> {
            txTemplate.execute(status -> {
                userRepository.findById(userId);
                bothPlainReadsDone.countDown();
                awaitQuietly(bothPlainReadsDone);
                growthService.grantExp(userId, "TXB", 1002L, 50);
                return null;
            });
            return null;
        };

        ExecutorService pool = Executors.newFixedThreadPool(2);
        List<Future<Void>> futures = pool.invokeAll(List.of(txA, txB));
        pool.shutdown();
        assertThat(pool.awaitTermination(10, TimeUnit.SECONDS)).isTrue();
        for (Future<Void> future : futures) {
            future.get(); // 스레드 내부 예외를 여기서 드러낸다
        }

        User reloaded = userRepository.findById(userId).orElseThrow();
        assertThat(reloaded.getTotalExp())
                .as("두 완료(30 + 50)가 모두 반영돼야 한다 — 유실되면 락이 무력화된 것")
                .isEqualTo(80);
    }

    private static void awaitQuietly(CountDownLatch latch) {
        try {
            latch.await(5, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
