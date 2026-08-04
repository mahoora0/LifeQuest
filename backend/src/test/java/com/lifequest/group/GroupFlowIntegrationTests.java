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
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class GroupFlowIntegrationTests {
    @Autowired AuthService auth; @Autowired UserRepository users; @Autowired GroupService groups;
    @Autowired GroupMembershipService memberships; @Autowired GroupChatService chat;
    @Autowired GroupQuestService quests; @Autowired GroupMemberRepository memberRepository;

    @Test
    void publicJoinOwnerTransferChatAndQuestFlow() {
        User owner=user("owner"); User member=user("member");
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

    private User user(String prefix){String token=UUID.randomUUID().toString().substring(0,8);String email=prefix+token+"@lifequest.test";auth.signup(new SignupRequest(email,"password123",prefix+token));return users.findByEmailIgnoreCase(email).orElseThrow();}
}
