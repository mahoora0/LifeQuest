package com.lifequest.group;

import com.lifequest.common.exception.*;
import com.lifequest.group.dto.*;
import com.lifequest.user.*;
import java.time.*;
import java.util.List;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GroupService {
    private final GroupRepository groups; private final GroupMemberRepository members; private final GroupQuestRepository quests; private final GroupQuestParticipantRepository participants; private final GroupChatMessageRepository messages; private final UserRepository users; private final Clock clock;
    public GroupService(GroupRepository groups,GroupMemberRepository members,GroupQuestRepository quests,GroupQuestParticipantRepository participants,GroupChatMessageRepository messages,UserRepository users,Clock clock){this.groups=groups;this.members=members;this.quests=quests;this.participants=participants;this.messages=messages;this.users=users;this.clock=clock;}

    @Transactional public GroupResponse create(Long userId,CreateGroupRequest request){
        validateMaxMembers(request.maxMembers());
        LocalDateTime now=now(); User owner=user(userId);
        Group group=groups.save(new Group(owner,required(request.name(),2,100),required(request.description(),1,500),request.visibility(),request.maxMembers(),now));
        members.save(GroupMember.owner(group,owner,now)); return response(group,userId,true);
    }
    @Transactional(readOnly=true) public List<GroupSummaryResponse> mine(Long userId){return members.findActiveGroups(userId).stream().map(m->summary(m.getGroup(),m)).toList();}
    @Transactional(readOnly=true) public PagedResponse<GroupSummaryResponse> search(Long userId,String query,int page,int size){
        validatePage(page,size); String keyword=required(query,1,100);
        Page<Group> result=groups.searchPublic(keyword,PageRequest.of(page,size));
        return PagedResponse.from(result,g->summary(g,members.findByGroupIdAndUserId(g.getId(),userId).orElse(null)));
    }
    @Transactional(readOnly=true) public GroupResponse detail(Long groupId,Long userId){
        Group group=groups.findById(groupId).orElseThrow(()->new BusinessException(ErrorCode.GROUP_NOT_FOUND));
        GroupMember membership=members.findByGroupIdAndUserId(groupId,userId).orElse(null);
        boolean active=membership!=null&&membership.getStatus()==GroupMemberStatus.ACTIVE;
        boolean invited=membership!=null&&membership.getStatus()==GroupMemberStatus.INVITED&&membership.getExpiresAt().isAfter(now());
        if(group.getStatus()==GroupStatus.ARCHIVED&&!active) throw new BusinessException(ErrorCode.GROUP_NOT_FOUND);
        if(group.getVisibility()==GroupVisibility.PRIVATE&&!active&&!invited) throw new BusinessException(ErrorCode.GROUP_NOT_FOUND);
        return response(group,userId,active);
    }
    @Transactional public GroupResponse update(Long groupId,Long userId,UpdateGroupRequest request){
        validateMaxMembers(request.maxMembers());
        Group group=lockedOwner(groupId,userId); requireActive(group); expireInvitations(groupId);
        long reserved=members.countByGroupIdAndStatus(groupId,GroupMemberStatus.ACTIVE)+members.countValidInvitations(groupId,now());
        if(request.maxMembers()<reserved) throw new BusinessException(ErrorCode.GROUP_FULL);
        group.update(required(request.name(),2,100),required(request.description(),1,500),request.visibility(),request.maxMembers(),now()); return response(group,userId,true);
    }
    @Transactional public void archive(Long groupId,Long userId){Group group=lockedOwner(groupId,userId);requireActive(group);group.archive(now());}
    @Transactional public void deletePermanently(Long groupId,Long userId){
        Group group=lockedOwner(groupId,userId);
        if(group.getStatus()!=GroupStatus.ARCHIVED)throw new BusinessException(ErrorCode.GROUP_PERMANENT_DELETE_REQUIRES_ARCHIVED);
        // 공동 완료 EXP는 이후 레벨·보상 계산에도 쓰이는 감사 이력이다. 지급을 되감지
        // 않은 채 출처만 지우지 않도록 완료 퀘스트가 있는 그룹은 영구 삭제하지 않는다.
        if(quests.existsByGroupIdAndStatus(groupId,GroupQuestStatus.COMPLETED))throw new BusinessException(ErrorCode.GROUP_PERMANENT_DELETE_BLOCKED_BY_COMPLETION);
        participants.deleteAllByGroupId(groupId);
        quests.deleteAllByGroupId(groupId);
        messages.deleteAllByGroupId(groupId);
        members.deleteAllByGroupId(groupId);
        groups.delete(group);
    }
    @Transactional public GroupResponse transferOwner(Long groupId,Long userId,Long targetId){
        Group group=lockedOwner(groupId,userId);requireActive(group);
        if(userId.equals(targetId)) throw new BusinessException(ErrorCode.INVALID_OWNER_TRANSFER);
        GroupMember oldOwner=members.findByGroupIdAndUserId(groupId,userId).orElseThrow(()->new BusinessException(ErrorCode.INVALID_OWNER_TRANSFER));
        GroupMember newOwner=members.findByGroupIdAndUserId(groupId,targetId).filter(m->m.getStatus()==GroupMemberStatus.ACTIVE&&m.getRole()==GroupMemberRole.MEMBER).orElseThrow(()->new BusinessException(ErrorCode.INVALID_OWNER_TRANSFER));
        LocalDateTime now=now();oldOwner.changeRole(GroupMemberRole.MEMBER,now);newOwner.changeRole(GroupMemberRole.OWNER,now);group.transferOwner(newOwner.getUser(),now);return response(group,userId,true);
    }
    Group lockedOwner(Long groupId,Long userId){Group g=groups.findByIdForUpdate(groupId).orElseThrow(()->new BusinessException(ErrorCode.GROUP_NOT_FOUND));if(!g.getOwner().getId().equals(userId))throw new BusinessException(ErrorCode.GROUP_OWNER_REQUIRED);return g;}
    void requireActive(Group group){if(group.getStatus()!=GroupStatus.ACTIVE)throw new BusinessException(ErrorCode.GROUP_ARCHIVED);}
    void expireInvitations(Long groupId){LocalDateTime now=now();members.findExpiredInvitations(groupId,now).forEach(m->m.reject(now));}
    boolean hasCapacity(Group group){expireInvitations(group.getId());return members.countByGroupIdAndStatus(group.getId(),GroupMemberStatus.ACTIVE)+members.countValidInvitations(group.getId(),now())<group.getMaxMembers();}
    private GroupResponse response(Group group,Long userId,boolean full){
        GroupMember mine=members.findByGroupIdAndUserId(group.getId(),userId).orElse(null); long count=members.countByGroupIdAndStatus(group.getId(),GroupMemberStatus.ACTIVE);
        long reserved=count+members.countValidInvitations(group.getId(),now());
        List<GroupMemberResponse> memberItems=full?members.findByGroupIdAndStatusOrderByIdAsc(group.getId(),GroupMemberStatus.ACTIVE,Pageable.unpaged()).stream().map(GroupMemberResponse::from).toList():null;
        boolean coopUnlocked=users.findById(userId).map(user->user.getLevel()>=5).orElse(false);
        List<GroupQuestResponse> recent=full&&coopUnlocked?quests.findRecent(group.getId(),PageRequest.of(0,3)).stream().map(GroupQuestResponse::from).toList():full?List.of():null;
        return new GroupResponse(group.getId(),group.getName(),group.getDescription(),group.getVisibility(),group.getMaxMembers(),count,group.getStatus(),group.getOwner().getId(),group.getOwner().getNickname(),mine==null?null:mine.getRole(),mine==null?null:mine.getStatus(),group.getStatus()==GroupStatus.ACTIVE&&reserved<group.getMaxMembers(),memberItems,recent,group.getCreatedAt(),group.getUpdatedAt());
    }
    private GroupSummaryResponse summary(Group group,GroupMember mine){long count=members.countByGroupIdAndStatus(group.getId(),GroupMemberStatus.ACTIVE);long reserved=count+members.countValidInvitations(group.getId(),now());return new GroupSummaryResponse(group.getId(),group.getName(),group.getDescription(),(int)count,group.getMaxMembers(),group.getStatus()==GroupStatus.ACTIVE&&reserved<group.getMaxMembers(),mine==null?null:mine.getRole(),mine==null?null:mine.getStatus(),group.getStatus());}
    private User user(Long id){return users.findById(id).orElseThrow(()->new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));}
    private LocalDateTime now(){return LocalDateTime.now(clock);}
    private static String required(String value,int min,int max){String v=value==null?"":value.trim();if(v.length()<min||v.length()>max)throw new BusinessException(ErrorCode.VALIDATION_FAILED);return v;}
    private static void validatePage(int page,int size){if(page<0||size<1||size>50)throw new BusinessException(ErrorCode.VALIDATION_FAILED);}
    private static void validateMaxMembers(int maxMembers){if(maxMembers<2||maxMembers>100)throw new BusinessException(ErrorCode.VALIDATION_FAILED);}
}
