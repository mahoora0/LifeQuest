package com.lifequest.group;

import com.lifequest.common.exception.*;
import com.lifequest.group.dto.*;
import com.lifequest.user.*;
import java.time.*;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GroupMembershipService {
    private final GroupRepository groups; private final GroupMemberRepository members; private final UserRepository users; private final GroupService groupService; private final Clock clock;
    public GroupMembershipService(GroupRepository groups,GroupMemberRepository members,UserRepository users,GroupService groupService,Clock clock){this.groups=groups;this.members=members;this.users=users;this.groupService=groupService;this.clock=clock;}

    @Transactional public GroupMemberResponse invite(Long groupId,Long ownerId,Long targetId){
        if(ownerId.equals(targetId))throw new BusinessException(ErrorCode.CANNOT_INVITE_SELF);
        Group group=groupService.lockedOwner(groupId,ownerId);groupService.requireActive(group);groupService.expireInvitations(groupId);
        if(!groupService.hasCapacity(group))throw new BusinessException(ErrorCode.GROUP_FULL);
        User target=user(targetId);User owner=user(ownerId);LocalDateTime now=now();
        GroupMember existing=members.findByGroupIdAndUserId(groupId,targetId).orElse(null);
        if(existing!=null&&activeOrPending(existing))throw new BusinessException(ErrorCode.GROUP_MEMBERSHIP_ALREADY_EXISTS);
        GroupMember result;
        if(existing==null)result=members.save(GroupMember.invitation(group,target,owner,now));else{existing.invite(owner,now);result=existing;}
        return GroupMemberResponse.from(result);
    }
    @Transactional public GroupMemberResponse requestJoin(Long groupId,Long userId){
        Group group=groups.findByIdForUpdate(groupId).orElseThrow(()->new BusinessException(ErrorCode.GROUP_NOT_FOUND));groupService.requireActive(group);
        if(group.getVisibility()!=GroupVisibility.PUBLIC)throw new BusinessException(ErrorCode.GROUP_NOT_FOUND);
        groupService.expireInvitations(groupId);if(!groupService.hasCapacity(group))throw new BusinessException(ErrorCode.GROUP_FULL);
        GroupMember existing=members.findByGroupIdAndUserId(groupId,userId).orElse(null);
        if(existing!=null&&activeOrPending(existing))throw new BusinessException(ErrorCode.GROUP_MEMBERSHIP_ALREADY_EXISTS);
        LocalDateTime now=now();GroupMember result;
        if(existing==null)result=members.save(GroupMember.joinRequest(group,user(userId),now));else{existing.requestJoin(now);result=existing;}
        return GroupMemberResponse.from(result);
    }
    @Transactional(noRollbackFor = BusinessException.class) public GroupMemberResponse acceptInvitation(Long memberId,Long userId){
        GroupMember snapshot=members.findById(memberId).filter(m->m.getUser().getId().equals(userId)&&m.getStatus()==GroupMemberStatus.INVITED).orElseThrow(()->new BusinessException(ErrorCode.GROUP_INVITATION_NOT_FOUND));
        Group group=groups.findByIdForUpdate(snapshot.getGroup().getId()).orElseThrow(()->new BusinessException(ErrorCode.GROUP_INVITATION_NOT_FOUND));
        GroupMember invitation=members.findByIdForUpdate(memberId).orElseThrow(()->new BusinessException(ErrorCode.GROUP_INVITATION_NOT_FOUND));
        groupService.requireActive(group);LocalDateTime now=now();
        if(invitation.isInvitationExpired(now)){invitation.reject(now);throw new BusinessException(ErrorCode.GROUP_INVITATION_EXPIRED);}
        if(invitation.getStatus()!=GroupMemberStatus.INVITED||!invitation.getUser().getId().equals(userId))throw new BusinessException(ErrorCode.GROUP_INVITATION_NOT_FOUND);
        groupService.expireInvitations(group.getId());long active=members.countByGroupIdAndStatus(group.getId(),GroupMemberStatus.ACTIVE);
        if(active>=group.getMaxMembers())throw new BusinessException(ErrorCode.GROUP_FULL);
        invitation.activate(now);return GroupMemberResponse.from(invitation);
    }
    @Transactional(noRollbackFor = BusinessException.class) public GroupMemberResponse declineInvitation(Long memberId,Long userId){
        GroupMember invitation=members.findByIdForUpdate(memberId).filter(m->m.getUser().getId().equals(userId)&&m.getStatus()==GroupMemberStatus.INVITED).orElseThrow(()->new BusinessException(ErrorCode.GROUP_INVITATION_NOT_FOUND));
        LocalDateTime now=now();if(invitation.isInvitationExpired(now)){invitation.reject(now);throw new BusinessException(ErrorCode.GROUP_INVITATION_EXPIRED);}invitation.reject(now);return GroupMemberResponse.from(invitation);
    }
    @Transactional public GroupMemberResponse respondJoin(Long groupId,Long ownerId,Long memberId,boolean approve){
        Group group=groupService.lockedOwner(groupId,ownerId);groupService.requireActive(group);
        GroupMember request=members.findByIdForUpdate(memberId).filter(m->m.getGroup().getId().equals(groupId)&&m.getStatus()==GroupMemberStatus.PENDING_APPROVAL).orElseThrow(()->new BusinessException(ErrorCode.GROUP_JOIN_REQUEST_NOT_FOUND));
        LocalDateTime now=now();if(approve){groupService.expireInvitations(groupId);if(!groupService.hasCapacity(group))throw new BusinessException(ErrorCode.GROUP_FULL);request.activate(now);}else request.reject(now);return GroupMemberResponse.from(request);
    }
    @Transactional public PagedResponse<GroupMemberResponse> invitations(Long userId,int page,int size){validatePage(page,size);LocalDateTime now=now();members.findExpiredInvitationsForUser(userId,now).forEach(m->m.reject(now));return PagedResponse.from(members.findByUserIdAndStatusAndExpiresAtAfterOrderByIdDesc(userId,GroupMemberStatus.INVITED,now,PageRequest.of(page,size)),GroupMemberResponse::from);}
    @Transactional(readOnly=true) public PagedResponse<GroupMemberResponse> joinRequests(Long groupId,Long ownerId,int page,int size){validatePage(page,size);Group group=groups.findById(groupId).orElseThrow(()->new BusinessException(ErrorCode.GROUP_NOT_FOUND));if(!group.getOwner().getId().equals(ownerId))throw new BusinessException(ErrorCode.GROUP_OWNER_REQUIRED);return PagedResponse.from(members.findByGroupIdAndStatusOrderByIdDesc(groupId,GroupMemberStatus.PENDING_APPROVAL,PageRequest.of(page,size)),GroupMemberResponse::from);}
    @Transactional(readOnly=true) public PagedResponse<GroupMemberResponse> activeMembers(Long groupId,Long userId,int page,int size){validatePage(page,size);requireMember(groupId,userId);return PagedResponse.from(members.findByGroupIdAndStatusOrderByIdAsc(groupId,GroupMemberStatus.ACTIVE,PageRequest.of(page,size)),GroupMemberResponse::from);}
    @Transactional public void leave(Long groupId,Long userId){GroupMember m=requireMember(groupId,userId);groupService.requireActive(m.getGroup());if(m.getRole()==GroupMemberRole.OWNER)throw new BusinessException(ErrorCode.OWNER_CANNOT_LEAVE);m.leave(now());}
    @Transactional public void remove(Long groupId,Long ownerId,Long targetId){Group group=groupService.lockedOwner(groupId,ownerId);groupService.requireActive(group);if(ownerId.equals(targetId))throw new BusinessException(ErrorCode.INVALID_OWNER_TRANSFER);GroupMember m=requireMember(groupId,targetId);m.remove(now());}
    private GroupMember requireMember(Long groupId,Long userId){return members.findByGroupIdAndUserId(groupId,userId).filter(m->m.getStatus()==GroupMemberStatus.ACTIVE).orElseThrow(()->new BusinessException(ErrorCode.GROUP_ACCESS_DENIED));}
    private boolean activeOrPending(GroupMember m){return m.getStatus()==GroupMemberStatus.ACTIVE||m.getStatus()==GroupMemberStatus.INVITED||m.getStatus()==GroupMemberStatus.PENDING_APPROVAL;}
    private User user(Long id){return users.findById(id).orElseThrow(()->new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));}
    private LocalDateTime now(){return LocalDateTime.now(clock);}
    private static void validatePage(int page,int size){if(page<0||size<1||size>50)throw new BusinessException(ErrorCode.VALIDATION_FAILED);}
}
