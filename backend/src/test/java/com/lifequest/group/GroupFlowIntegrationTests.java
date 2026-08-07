package com.lifequest.group;

import static org.assertj.core.api.Assertions.*;

import com.lifequest.auth.AuthService;
import com.lifequest.auth.dto.SignupRequest;
import com.lifequest.common.exception.*;
import com.lifequest.group.dto.*;
import com.lifequest.user.*;
import java.time.LocalDateTime;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class GroupFlowIntegrationTests {
    @Autowired AuthService auth; @Autowired UserRepository users; @Autowired GroupService groups;
    @Autowired GroupMembershipService memberships; @Autowired GroupChatService chat;
    @Autowired GroupQuestService quests; @Autowired GroupMemberRepository memberRepository;
    @Autowired JdbcTemplate jdbc;
    @Autowired org.springframework.transaction.PlatformTransactionManager txManager;

    @Test
    void publicJoinOwnerTransferChatAndQuestFlow() {
        User owner=user("owner"); User member=user("member");
        unlockCoop(owner,member);
        GroupResponse created=groups.create(owner.getId(),new CreateGroupRequest("주말 탐험대","함께 경험해요",GroupVisibility.PUBLIC,3));
        assertThat(created.activeMemberCount()).isEqualTo(1);
        assertThat(created.myRole()).isEqualTo(GroupMemberRole.OWNER);
        assertThat(groups.search(member.getId(),"탐험",0,20).content()).hasSize(1);

        GroupMemberResponse pending=memberships.requestJoin(created.id(),member.getId());
        assertThat(pending.status()).isEqualTo(GroupMemberStatus.PENDING_APPROVAL);
        memberships.respondJoin(created.id(),owner.getId(),pending.memberId(),true);
        assertThat(memberships.activeMembers(created.id(),member.getId(),0,20).content()).hasSize(2);

        GroupMessageResponse sent=chat.send(created.id(),member.getId(),"  토요일에 만나요  ");
        assertThat(sent.content()).isEqualTo("토요일에 만나요");
        assertThat(chat.get(created.id(),owner.getId(),null,null,50).messages()).extracting(GroupMessageResponse::id).containsExactly(sent.id());

        GroupQuestResponse quest=quests.create(created.id(),owner.getId(),new CreateGroupQuestRequest("한강 야경 산책","함께 한강을 산책해요","여의도 한강공원",LocalDateTime.now().plusDays(2)));
        assertThat(quests.list(created.id(),member.getId(),GroupQuestScope.UPCOMING,0,20).content()).hasSize(1);
        assertThat(quests.cancel(created.id(),owner.getId(),quest.id()).status()).isEqualTo(GroupQuestStatus.CANCELLED);

        groups.transferOwner(created.id(),owner.getId(),member.getId());
        assertThatThrownBy(()->groups.update(created.id(),owner.getId(),new UpdateGroupRequest("새 이름","새 설명",GroupVisibility.PUBLIC,3)))
                .isInstanceOfSatisfying(BusinessException.class,e->assertThat(e.errorCode()).isEqualTo(ErrorCode.GROUP_OWNER_REQUIRED));
        assertThat(groups.update(created.id(),member.getId(),new UpdateGroupRequest("새 이름","새 설명",GroupVisibility.PRIVATE,3)).ownerUserId()).isEqualTo(member.getId());
    }

    @Test
    void invitationReservesCapacityAndMembershipCanBeReused() {
        User owner=user("inviter"); User invited=user("invited"); User outsider=user("outsider");
        GroupResponse created=groups.create(owner.getId(),new CreateGroupRequest("소규모 그룹","두 명만 참여",GroupVisibility.PRIVATE,2));
        GroupMemberResponse invitation=memberships.invite(created.id(),owner.getId(),invited.getId());
        assertThat(invitation.status()).isEqualTo(GroupMemberStatus.INVITED);
        assertThat(groups.detail(created.id(),invited.getId()).joinable()).isFalse();
        assertThatThrownBy(()->memberships.invite(created.id(),owner.getId(),outsider.getId()))
                .isInstanceOfSatisfying(BusinessException.class,e->assertThat(e.errorCode()).isEqualTo(ErrorCode.GROUP_FULL));
        assertThat(memberships.acceptInvitation(invitation.memberId(),invited.getId()).status()).isEqualTo(GroupMemberStatus.ACTIVE);
        memberships.leave(created.id(),invited.getId());
        assertThat(memberRepository.findByGroupIdAndUserId(created.id(),invited.getId()).orElseThrow().getStatus()).isEqualTo(GroupMemberStatus.LEFT);
        assertThat(memberships.invite(created.id(),owner.getId(),invited.getId()).memberId()).isEqualTo(invitation.memberId());
    }

    @Test
    void invalidCapacityAndPrivateSearchAreRejected() {
        User owner=user("validation"); User viewer=user("viewer");
        assertThatThrownBy(()->groups.create(owner.getId(),new CreateGroupRequest("그룹","설명",GroupVisibility.PUBLIC,1))).isInstanceOf(BusinessException.class);
        groups.create(owner.getId(),new CreateGroupRequest("숨은 그룹","검색되지 않음",GroupVisibility.PRIVATE,10));
        assertThat(groups.search(viewer.getId(),"숨은",0,20).content()).isEmpty();
    }

    @Test
    void groupPermissionsAndOwnerLeaveRulesAreEnforced() {
        User owner=user("permissionOwner"); User outsider=user("permissionOutsider");
        unlockCoop(owner,outsider);
        GroupResponse created=groups.create(owner.getId(),new CreateGroupRequest("권한 그룹","권한을 검증합니다",GroupVisibility.PUBLIC,4));

        assertError(()->chat.get(created.id(),outsider.getId(),null,null,20),ErrorCode.GROUP_ACCESS_DENIED);
        assertError(()->chat.send(created.id(),outsider.getId(),"침입 메시지"),ErrorCode.GROUP_ACCESS_DENIED);
        assertError(()->quests.create(created.id(),outsider.getId(),new CreateGroupQuestRequest("권한 없는 일정","등록할 수 없습니다","서울",LocalDateTime.now().plusDays(1))),ErrorCode.GROUP_OWNER_REQUIRED);
        assertError(()->memberships.leave(created.id(),owner.getId()),ErrorCode.OWNER_CANNOT_LEAVE);
        assertError(()->groups.transferOwner(created.id(),owner.getId(),outsider.getId()),ErrorCode.INVALID_OWNER_TRANSFER);
    }

    @Test
    void chatSupportsLatestBeforeAndAfterPaginationWithoutDuplicates() {
        User owner=user("chatOwner");
        GroupResponse created=groups.create(owner.getId(),new CreateGroupRequest("채팅 그룹","페이지를 검증합니다",GroupVisibility.PRIVATE,3));
        GroupMessageResponse first=chat.send(created.id(),owner.getId(),"첫 번째");
        GroupMessageResponse second=chat.send(created.id(),owner.getId(),"두 번째");
        GroupMessageResponse third=chat.send(created.id(),owner.getId(),"세 번째");
        GroupMessageResponse fourth=chat.send(created.id(),owner.getId(),"네 번째");

        GroupMessagePageResponse latest=chat.get(created.id(),owner.getId(),null,null,2);
        assertThat(latest.messages()).extracting(GroupMessageResponse::id).containsExactly(third.id(),fourth.id());
        assertThat(latest.hasMoreBefore()).isTrue();
        assertThat(latest.latestId()).isEqualTo(fourth.id());

        GroupMessagePageResponse before=chat.get(created.id(),owner.getId(),third.id(),null,2);
        assertThat(before.messages()).extracting(GroupMessageResponse::id).containsExactly(first.id(),second.id());
        assertThat(before.hasMoreBefore()).isFalse();

        GroupMessagePageResponse after=chat.get(created.id(),owner.getId(),null,second.id(),10);
        assertThat(after.messages()).extracting(GroupMessageResponse::id).containsExactly(third.id(),fourth.id());
        // 폴링 호출자는 afterId 이전을 이미 갖고 있다. 여기서 true를 주면 과거 로딩 UI가 헛돈다.
        assertThat(after.hasMoreBefore()).isFalse();
        assertThat(chat.get(created.id(),owner.getId(),null,fourth.id(),10).messages()).isEmpty();
        assertError(()->chat.get(created.id(),owner.getId(),first.id(),second.id(),20),ErrorCode.VALIDATION_FAILED);
    }

    @Test
    void archivedGroupIsReadOnlyButKeepsMemberHistoryVisible() {
        User owner=user("archiveOwner"); User outsider=user("archiveOutsider");
        unlockCoop(owner);
        GroupResponse created=groups.create(owner.getId(),new CreateGroupRequest("보관 그룹","기록을 남깁니다",GroupVisibility.PUBLIC,3));
        chat.send(created.id(),owner.getId(),"보관 전 메시지");
        groups.archive(created.id(),owner.getId());

        assertThat(groups.detail(created.id(),owner.getId()).status()).isEqualTo(GroupStatus.ARCHIVED);
        assertThat(chat.get(created.id(),owner.getId(),null,null,20).messages()).hasSize(1);
        assertError(()->groups.detail(created.id(),outsider.getId()),ErrorCode.GROUP_NOT_FOUND);
        assertError(()->chat.send(created.id(),owner.getId(),"보관 후 메시지"),ErrorCode.GROUP_ARCHIVED);
        assertError(()->groups.update(created.id(),owner.getId(),new UpdateGroupRequest("변경 불가","보관 상태",GroupVisibility.PUBLIC,3)),ErrorCode.GROUP_ARCHIVED);
        assertError(()->quests.create(created.id(),owner.getId(),new CreateGroupQuestRequest("변경 불가","보관 상태","서울",LocalDateTime.now().plusDays(1))),ErrorCode.GROUP_ARCHIVED);
    }

    @Test
    void cancelledOrStartedGroupQuestCannotBeModifiedAgain() {
        User owner=user("questOwner");
        unlockCoop(owner);
        GroupResponse created=groups.create(owner.getId(),new CreateGroupRequest("일정 그룹","일정 상태를 검증합니다",GroupVisibility.PUBLIC,3));
        GroupQuestResponse cancelled=quests.create(created.id(),owner.getId(),new CreateGroupQuestRequest("취소할 일정","취소 후 변경 불가","서울숲",LocalDateTime.now().plusDays(2)));
        quests.cancel(created.id(),owner.getId(),cancelled.id());

        UpdateGroupQuestRequest update=new UpdateGroupQuestRequest("변경 일정","변경 설명","성수동",LocalDateTime.now().plusDays(3));
        assertError(()->quests.update(created.id(),owner.getId(),cancelled.id(),update),ErrorCode.GROUP_QUEST_CANCELLED);
        assertError(()->quests.cancel(created.id(),owner.getId(),cancelled.id()),ErrorCode.GROUP_QUEST_CANCELLED);

        GroupQuestResponse started=quests.create(created.id(),owner.getId(),new CreateGroupQuestRequest("시작한 일정","시작 후 변경 불가","한강",LocalDateTime.now().plusDays(1)));
        jdbc.update("update group_quests set scheduled_at=? where id=?",LocalDateTime.now().minusMinutes(1),started.id());
        assertError(()->quests.update(created.id(),owner.getId(),started.id(),update),ErrorCode.GROUP_QUEST_ALREADY_STARTED);
        assertError(()->quests.cancel(created.id(),owner.getId(),started.id()),ErrorCode.GROUP_QUEST_ALREADY_STARTED);
    }

    @Test
    void expiredInvitationIsRejectedAndCannotBeAccepted() {
        User owner=user("expiryOwner"); User invited=user("expiryInvited");
        GroupResponse created=groups.create(owner.getId(),new CreateGroupRequest("초대 만료 그룹","만료를 검증합니다",GroupVisibility.PRIVATE,3));
        GroupMemberResponse invitation=memberships.invite(created.id(),owner.getId(),invited.getId());
        jdbc.update("update group_members set expires_at=? where id=?",LocalDateTime.now().minusSeconds(1),invitation.memberId());

        assertError(()->memberships.acceptInvitation(invitation.memberId(),invited.getId()),ErrorCode.GROUP_INVITATION_EXPIRED);
        assertThat(memberRepository.findById(invitation.memberId()).orElseThrow().getStatus()).isEqualTo(GroupMemberStatus.REJECTED);
        assertThat(memberships.invitations(invited.getId(),0,20).content()).isEmpty();
    }

    @Test
    void privateGroupHidesItselfFromNonMembersAndRejectsJoinRequests() {
        User owner=user("privateOwner"); User outsider=user("privateOutsider");
        GroupResponse created=groups.create(owner.getId(),new CreateGroupRequest("비공개 그룹","초대로만 들어옵니다",GroupVisibility.PRIVATE,5));

        // 존재 자체를 숨겨야 하므로 403이 아니라 404여야 한다.
        assertError(()->groups.detail(created.id(),outsider.getId()),ErrorCode.GROUP_NOT_FOUND);
        assertError(()->memberships.requestJoin(created.id(),outsider.getId()),ErrorCode.GROUP_NOT_FOUND);
        assertError(()->memberships.invite(created.id(),owner.getId(),owner.getId()),ErrorCode.CANNOT_INVITE_SELF);

        // 유효 초대를 받으면 그때부터는 상세를 볼 수 있다.
        memberships.invite(created.id(),owner.getId(),outsider.getId());
        assertThat(groups.detail(created.id(),outsider.getId()).name()).isEqualTo("비공개 그룹");
    }

    @Test
    void plainMemberCannotRemoveAnotherMember() {
        User owner=user("removeOwner"); User member=user("removeMember"); User other=user("removeOther");
        GroupResponse created=groups.create(owner.getId(),new CreateGroupRequest("내보내기 그룹","권한을 검증합니다",GroupVisibility.PUBLIC,5));
        for(User joiner:new User[]{member,other}){
            GroupMemberResponse pending=memberships.requestJoin(created.id(),joiner.getId());
            memberships.respondJoin(created.id(),owner.getId(),pending.memberId(),true);
        }

        assertError(()->memberships.remove(created.id(),member.getId(),other.getId()),ErrorCode.GROUP_OWNER_REQUIRED);
        assertThat(memberRepository.findByGroupIdAndUserId(created.id(),other.getId()).orElseThrow().getStatus())
                .isEqualTo(GroupMemberStatus.ACTIVE);

        // 그룹장이 스스로를 내보내는 것도 탈퇴와 같은 안내를 받아야 한다.
        assertError(()->memberships.remove(created.id(),owner.getId(),owner.getId()),ErrorCode.OWNER_CANNOT_LEAVE);
    }

    @Test
    void ownerTransferRollsBackOwnerColumnAndBothRolesTogether() {
        User owner=user("rollbackOwner"); User member=user("rollbackMember");
        GroupResponse created=groups.create(owner.getId(),new CreateGroupRequest("위임 그룹","롤백을 검증합니다",GroupVisibility.PUBLIC,5));
        GroupMemberResponse pending=memberships.requestJoin(created.id(),member.getId());
        memberships.respondJoin(created.id(),owner.getId(),pending.memberId(),true);

        // owner 컬럼과 두 role이 한 트랜잭션에 묶여 있는지 확인한다. 셋 중 하나라도
        // 별도 트랜잭션에서 쓰였다면 바깥 롤백 후에도 그 변경만 남는다.
        var template=new org.springframework.transaction.support.TransactionTemplate(txManager);
        template.executeWithoutResult(status->{
            // 롤백 전에 실제로 위임이 일어났음을 확인해야 이 테스트가 공허해지지 않는다.
            assertThat(groups.transferOwner(created.id(),owner.getId(),member.getId()).ownerUserId())
                    .isEqualTo(member.getId());
            status.setRollbackOnly();
        });

        assertThat(jdbc.queryForObject("select owner_user_id from quest_groups where id=?",Long.class,created.id()))
                .isEqualTo(owner.getId());
        assertThat(role(created.id(),owner.getId())).isEqualTo(GroupMemberRole.OWNER.name());
        assertThat(role(created.id(),member.getId())).isEqualTo(GroupMemberRole.MEMBER.name());
    }

    @Test
    void participantsApplyAndReceiveExpOnceWhenOwnerCompletesTogether() {
        User owner=user("coopOwner");
        User member=user("coopMember");
        User departed=user("coopDeparted");
        unlockCoop(owner,member,departed);
        GroupResponse created=groups.create(owner.getId(),new CreateGroupRequest(
                "협동 원정대","공동 완료와 보상을 검증합니다",GroupVisibility.PUBLIC,5));
        for(User joiner:new User[]{member,departed}){
            GroupMemberResponse pending=memberships.requestJoin(created.id(),joiner.getId());
            memberships.respondJoin(created.id(),owner.getId(),pending.memberId(),true);
        }

        GroupQuestResponse quest=quests.create(created.id(),owner.getId(),new CreateGroupQuestRequest(
                "한강 공동 산책","참여자와 함께 완료합니다","한강",LocalDateTime.now().plusHours(2)));
        assertThat(quests.listMine(member.getId(),GroupQuestScope.UPCOMING,0,20).content())
                .extracting(GroupQuestResponse::id).contains(quest.id());
        assertThat(quests.apply(created.id(),owner.getId(),quest.id()).myParticipationStatus())
                .isEqualTo(GroupQuestParticipationStatus.APPLIED);
        assertThat(quests.apply(created.id(),member.getId(),quest.id()).participantCount()).isEqualTo(2);
        quests.apply(created.id(),departed.getId(),quest.id());
        memberships.leave(created.id(),departed.getId());

        jdbc.update("update group_quests set scheduled_at=? where id=?",LocalDateTime.now().minusMinutes(1),quest.id());
        GroupQuestResponse completed=quests.complete(created.id(),owner.getId(),quest.id());

        assertThat(completed.status()).isEqualTo(GroupQuestStatus.COMPLETED);
        assertThat(completed.participantCount()).isEqualTo(2);
        assertThat(completed.participants()).extracting(GroupQuestParticipantResponse::userId)
                .containsExactlyInAnyOrder(owner.getId(),member.getId());
        assertThat(users.findById(owner.getId()).orElseThrow().getTotalExp()).isEqualTo(1040);
        assertThat(users.findById(member.getId()).orElseThrow().getTotalExp()).isEqualTo(1040);
        assertThat(users.findById(departed.getId()).orElseThrow().getTotalExp()).isEqualTo(1000);

        // 완료 API 재호출은 성공하지만 기존 결과만 반환하고 EXP를 재지급하지 않는다.
        assertThat(quests.complete(created.id(),owner.getId(),quest.id()).status())
                .isEqualTo(GroupQuestStatus.COMPLETED);
        assertThat(users.findById(member.getId()).orElseThrow().getTotalExp()).isEqualTo(1040);
        assertThat(quests.listMine(member.getId(),GroupQuestScope.PAST,0,20).content())
                .extracting(GroupQuestResponse::id).contains(quest.id());
    }

    @Test
    void coopParticipationRequiresLevelFiveAndClosesAtStart() {
        User owner=user("lockedCoopOwner");
        User member=user("lockedCoopMember");
        unlockCoop(owner);
        GroupResponse created=groups.create(owner.getId(),new CreateGroupRequest(
                "해금 검증단","협동 레벨을 검증합니다",GroupVisibility.PUBLIC,3));
        GroupMemberResponse pending=memberships.requestJoin(created.id(),member.getId());
        memberships.respondJoin(created.id(),owner.getId(),pending.memberId(),true);
        GroupQuestResponse quest=quests.create(created.id(),owner.getId(),new CreateGroupQuestRequest(
                "레벨 제한 원정","레벨 제한 설명","서울",LocalDateTime.now().plusHours(1)));

        assertError(()->quests.apply(created.id(),member.getId(),quest.id()),ErrorCode.QUEST_FEATURE_LOCKED);
        unlockCoop(member);
        quests.apply(created.id(),member.getId(),quest.id());
        quests.withdraw(created.id(),member.getId(),quest.id());
        jdbc.update("update group_quests set scheduled_at=? where id=?",LocalDateTime.now().minusMinutes(1),quest.id());
        assertError(()->quests.apply(created.id(),member.getId(),quest.id()),ErrorCode.GROUP_QUEST_PARTICIPATION_CLOSED);
        assertError(()->quests.complete(created.id(),owner.getId(),quest.id()),ErrorCode.GROUP_QUEST_NO_PARTICIPANTS);
    }

    private String role(Long groupId,Long userId){
        return jdbc.queryForObject("select role from group_members where group_id=? and user_id=?",String.class,groupId,userId);
    }

    private void unlockCoop(User... unlockedUsers){
        for(User user:unlockedUsers){
            jdbc.update("update users set total_exp=1000, level=5 where id=?",user.getId());
        }
        users.flush();
    }

    private void assertError(org.assertj.core.api.ThrowableAssert.ThrowingCallable action,ErrorCode code){
        assertThatThrownBy(action).isInstanceOfSatisfying(BusinessException.class,e->assertThat(e.errorCode()).isEqualTo(code));
    }

    private User user(String prefix){String token=UUID.randomUUID().toString().substring(0,8);String email=prefix+token+"@lifequest.test";auth.signup(new SignupRequest(email,"password123",prefix+token));return users.findByEmailIgnoreCase(email).orElseThrow();}
}
