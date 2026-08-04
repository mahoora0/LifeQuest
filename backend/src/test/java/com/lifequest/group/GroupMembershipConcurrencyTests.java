package com.lifequest.group;

import static org.assertj.core.api.Assertions.assertThat;

import com.lifequest.auth.AuthService;
import com.lifequest.auth.dto.SignupRequest;
import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.group.dto.CreateGroupRequest;
import com.lifequest.group.dto.GroupResponse;
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
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
class GroupMembershipConcurrencyTests {

    @Autowired AuthService auth;
    @Autowired UserRepository users;
    @Autowired GroupService groups;
    @Autowired GroupMembershipService memberships;
    @Autowired GroupMemberRepository memberRepository;

    @Test
    void concurrentInvitationsCannotReserveBeyondMaxMembers() throws Exception {
        User owner=user("capacityOwner");
        User first=user("capacityFirst");
        User second=user("capacitySecond");
        GroupResponse group=groups.create(owner.getId(),new CreateGroupRequest("동시 초대 그룹","남은 한 자리를 검증합니다",GroupVisibility.PRIVATE,2));
        CountDownLatch ready=new CountDownLatch(2);
        CountDownLatch start=new CountDownLatch(1);
        ExecutorService executor=Executors.newFixedThreadPool(2);
        try {
            Future<ErrorCode> firstResult=executor.submit(()->invite(group.id(),owner.getId(),first.getId(),ready,start));
            Future<ErrorCode> secondResult=executor.submit(()->invite(group.id(),owner.getId(),second.getId(),ready,start));
            ready.await();
            start.countDown();

            int successes=0;
            int fullErrors=0;
            for(Future<ErrorCode> future:java.util.List.of(firstResult,secondResult)) {
                ErrorCode result=future.get();
                if(result==null) successes++;
                if(result==ErrorCode.GROUP_FULL) fullErrors++;
            }
            assertThat(successes).isEqualTo(1);
            assertThat(fullErrors).isEqualTo(1);
            assertThat(memberRepository.countValidInvitations(group.id(),java.time.LocalDateTime.now())).isEqualTo(1);
        } finally {
            executor.shutdownNow();
        }
    }

    private ErrorCode invite(Long groupId,Long ownerId,Long targetId,CountDownLatch ready,CountDownLatch start) throws InterruptedException {
        ready.countDown();
        start.await();
        try {
            memberships.invite(groupId,ownerId,targetId);
            return null;
        } catch(BusinessException exception) {
            return exception.errorCode();
        }
    }

    private User user(String prefix) {
        String suffix=UUID.randomUUID().toString().substring(0,8);
        String email=prefix+suffix+"@lifequest.test";
        auth.signup(new SignupRequest(email,"password123",prefix+suffix));
        return users.findByEmailIgnoreCase(email).orElseThrow();
    }
}
