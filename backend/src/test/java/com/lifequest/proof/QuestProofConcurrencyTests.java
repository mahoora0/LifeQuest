package com.lifequest.proof;

import static org.assertj.core.api.Assertions.assertThat;

import com.lifequest.growth.ExpLogRepository;
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
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.Collectors;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

/**
 * 동시 투표에서 표와 EXP가 정확한지 검증한다.
 *
 * <p>순차 요청만 보내는 {@link QuestProofFlowIntegrationTests}로는 이 결함이 드러나지 않는다.
 * 표 수는 엔티티 필드 증가로 갱신되므로, 게시물 행을 잠그지 않으면 두 요청이 같은 값을 읽고
 * 같은 값을 써서 한 표가 사라진다 — 투표 테이블에는 3건이 있는데 카운터는 2가 되고, 판정도
 * 그만큼 늦어진다.
 *
 * <p>서비스를 직접 호출한다. MockMvc를 쓰면 스레드마다 요청 컨텍스트를 따로 세워야 해서
 * 검증하려는 잠금 동작이 아니라 테스트 배선이 결과를 좌우한다.
 */
@SpringBootTest
@ActiveProfiles("test")
class QuestProofConcurrencyTests {

    private static final int DAILY_VOTE_EXP_GRANTS = 5;

    @Autowired
    private QuestProofService questProofService;

    @Autowired
    private QuestRepository questRepository;

    @Autowired
    private UserDailyQuestRepository userDailyQuestRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private QuestCompletionService questCompletionService;

    @Autowired
    private QuestProofPostRepository postRepository;

    @Autowired
    private ExpLogRepository expLogRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    /** 이 클래스가 만든 사용자·퀘스트. 뒷정리 대상이다. */
    private final List<Long> createdUserIds = new ArrayList<>();
    private final List<Long> createdQuestIds = new ArrayList<>();

    /**
     * 커밋된 데이터를 직접 지운다.
     *
     * <p>이 클래스는 잠금 동작을 보려고 실제 트랜잭션을 커밋하므로 {@code @Transactional}
     * 롤백에 기댈 수 없다. 남겨 두면 H2 인메모리 DB를 공유하는 다른 테스트에 새어 나가는데,
     * 사용자 ID를 리터럴로 고정한 테스트가 있어 실행 순서에 따라 그쪽이 깨진다.
     */
    @AfterEach
    void cleanUp() {
        if (createdUserIds.isEmpty()) {
            return;
        }
        String users = inClause(createdUserIds);
        jdbcTemplate.update("DELETE FROM quest_proof_votes WHERE voter_user_id IN " + users);
        jdbcTemplate.update("DELETE FROM quest_proof_comments WHERE author_user_id IN " + users);
        jdbcTemplate.update(
                "DELETE FROM quest_proof_photos WHERE post_id IN "
                        + "(SELECT id FROM quest_proof_posts WHERE user_id IN " + users + ")");
        jdbcTemplate.update("DELETE FROM quest_proof_posts WHERE user_id IN " + users);
        jdbcTemplate.update("DELETE FROM exp_logs WHERE user_id IN " + users);
        jdbcTemplate.update("DELETE FROM quest_completions WHERE user_id IN " + users);
        jdbcTemplate.update("DELETE FROM user_daily_quests WHERE user_id IN " + users);
        jdbcTemplate.update("DELETE FROM users WHERE id IN " + users);
        if (!createdQuestIds.isEmpty()) {
            jdbcTemplate.update("DELETE FROM quests WHERE id IN " + inClause(createdQuestIds));
        }
        createdUserIds.clear();
        createdQuestIds.clear();
    }

    private static String inClause(List<Long> ids) {
        return ids.stream().map(String::valueOf).collect(Collectors.joining(",", "(", ")"));
    }

    @Test
    void 동시_투표가_표를_유실하지_않는다() throws Exception {
        User author = createUser("concurrent-author@proof.test", "동시작성자");
        long postId = createPost(author);

        List<User> voters = new ArrayList<>();
        for (int index = 0; index < 3; index++) {
            voters.add(createUser(
                    "concurrent-voter%d@proof.test".formatted(index), "동시투표자%d".formatted(index)));
        }

        runTogether(voters.stream()
                .map(voter -> (Runnable) () ->
                        questProofService.vote(voter.getId(), postId, ProofVoteChoice.AGREE))
                .toList());

        QuestProofPost post = postRepository.findById(postId).orElseThrow();
        assertThat(post.getAgreeCount()).isEqualTo(3);
        assertThat(post.decidedVoteCount()).isEqualTo(3);
        // 표가 하나라도 유실되면 판정이 시작되지 않아 VOTING에 머무른다.
        assertThat(post.getStatus()).isEqualTo(ProofPostStatus.VERIFIED);
    }

    @Test
    void 한_사용자의_동시_투표가_하루_EXP_한도를_넘지_않는다() throws Exception {
        User voter = createUser("concurrent-limit@proof.test", "동시한도투표자");

        // 한도보다 많은 게시물에 동시에 투표한다. 잠금이 없으면 한도 검사가 모두 통과해
        // 지급 횟수가 한도를 넘는다.
        int attempts = DAILY_VOTE_EXP_GRANTS + 3;
        List<Long> postIds = new ArrayList<>();
        for (int index = 0; index < attempts; index++) {
            User author = createUser(
                    "concurrent-limit-author%d@proof.test".formatted(index),
                    "동시한도작성자%d".formatted(index));
            postIds.add(createPost(author));
        }

        AtomicInteger granted = new AtomicInteger();
        runTogether(postIds.stream()
                .map(postId -> (Runnable) () ->
                        granted.addAndGet(
                                questProofService.vote(voter.getId(), postId, ProofVoteChoice.AGREE)
                                        .expGained()))
                .toList());

        assertThat(granted.get()).isEqualTo(DAILY_VOTE_EXP_GRANTS);
        assertThat(expLogRepository.countByUserIdAndSourceTypeAndCreatedAtGreaterThanEqual(
                voter.getId(), "PROOF_VOTE", Instant.EPOCH))
                .isEqualTo(DAILY_VOTE_EXP_GRANTS);
    }

    /** 모든 작업을 같은 순간에 풀어 실제로 겹치게 한다. */
    private void runTogether(List<Runnable> tasks) throws Exception {
        ExecutorService executor = Executors.newFixedThreadPool(tasks.size());
        CountDownLatch start = new CountDownLatch(1);
        List<Future<?>> futures = new ArrayList<>();
        try {
            for (Runnable task : tasks) {
                futures.add(executor.submit(() -> {
                    start.await();
                    task.run();
                    return null;
                }));
            }
            start.countDown();
            for (Future<?> future : futures) {
                future.get(30, TimeUnit.SECONDS);
            }
        } finally {
            executor.shutdownNow();
        }
    }

    private long createPost(User author) {
        long completionId = completeQuest(author);
        return questProofService
                .create(author.getId(), completionId, "동시성 픽스처", List.of(fakePhoto()))
                .postId();
    }

    private org.springframework.mock.web.MockMultipartFile fakePhoto() {
        return new org.springframework.mock.web.MockMultipartFile(
                "photos", "proof.jpg", "image/jpeg", "fake-image-bytes".getBytes());
    }

    private long completeQuest(User user) {
        Quest quest = questRepository.save(new Quest(
                "동시성 테스트 퀘스트", "픽스처", QuestGrade.NORMAL, QuestCadence.DAILY,
                CompletionType.SELF_REPORT, 10,
                null, null, null, null, null,
                QuestCreator.SYSTEM, true));
        createdQuestIds.add(quest.getId());

        UserDailyQuest assignment = userDailyQuestRepository.save(new UserDailyQuest(
                user.getId(), quest.getId(), LocalDate.now(), LocalDateTime.now().plusDays(1)));

        return questCompletionService
                .complete(user.getId(), assignment.getId(), QuestCompletionRequest.empty())
                .completionId();
    }

    private User createUser(String email, String nickname) {
        User user = userRepository.save(User.local(email, "{noop}password123", nickname));
        createdUserIds.add(user.getId());
        return user;
    }
}
