package com.lifequest.group;

import static org.assertj.core.api.Assertions.assertThat;

import com.lifequest.auth.AuthService;
import com.lifequest.auth.dto.SignupRequest;
import com.lifequest.group.dto.CreateGroupQuestRequest;
import com.lifequest.group.dto.CreateGroupRequest;
import com.lifequest.group.dto.GroupMemberResponse;
import com.lifequest.group.dto.GroupQuestResponse;
import com.lifequest.group.dto.GroupResponse;
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class GroupQuestCompletionConcurrencyTests {
    @Autowired AuthService auth;
    @Autowired UserRepository users;
    @Autowired GroupService groups;
    @Autowired GroupMembershipService memberships;
    @Autowired GroupQuestService quests;
    @Autowired JdbcTemplate jdbc;

    @Test
    void concurrentCompletionRewardsEachParticipantOnlyOnce() throws Exception {
        User owner = user("concurrentCoopOwner");
        User member = user("concurrentCoopMember");
        unlockCoop(owner, member);
        GroupResponse group = groups.create(owner.getId(), new CreateGroupRequest(
            "동시 완료 원정대", "공동 완료 중복 지급을 검증합니다", GroupVisibility.PUBLIC, 3));
        GroupMemberResponse pending = memberships.requestJoin(group.id(), member.getId());
        memberships.respondJoin(group.id(), owner.getId(), pending.memberId(), true);
        GroupQuestResponse quest = quests.create(group.id(), owner.getId(), new CreateGroupQuestRequest(
            "동시 공동 완료", "한 번만 지급되어야 합니다", "서울", LocalDateTime.now().plusHours(1)));
        quests.apply(group.id(), member.getId(), quest.id());
        jdbc.update("update group_quests set scheduled_at=? where id=?",
            LocalDateTime.now().minusMinutes(1), quest.id());

        CountDownLatch ready = new CountDownLatch(2);
        Callable<GroupQuestStatus> complete = () -> {
            ready.countDown();
            ready.await(5, TimeUnit.SECONDS);
            return quests.complete(group.id(), owner.getId(), quest.id()).status();
        };
        ExecutorService pool = Executors.newFixedThreadPool(2);
        List<Future<GroupQuestStatus>> futures = pool.invokeAll(List.of(complete, complete));
        pool.shutdown();
        assertThat(pool.awaitTermination(10, TimeUnit.SECONDS)).isTrue();
        for (Future<GroupQuestStatus> future : futures) {
            assertThat(future.get()).isEqualTo(GroupQuestStatus.COMPLETED);
        }

        assertThat(users.findById(member.getId()).orElseThrow().getTotalExp()).isEqualTo(1040);
        Integer grants = jdbc.queryForObject(
            "select count(*) from exp_logs where user_id=? and source_type='GROUP_QUEST_COMPLETION' and source_id=?",
            Integer.class, member.getId(), quest.id());
        assertThat(grants).isEqualTo(1);
    }

    private void unlockCoop(User... unlockedUsers) {
        for (User user : unlockedUsers) {
            jdbc.update("update users set total_exp=1000, level=5 where id=?", user.getId());
        }
    }

    private User user(String prefix) {
        String suffix = UUID.randomUUID().toString().substring(0, 8);
        String email = prefix + suffix + "@lifequest.test";
        auth.signup(new SignupRequest(email, "password123", prefix + suffix));
        return users.findByEmailIgnoreCase(email).orElseThrow();
    }
}
