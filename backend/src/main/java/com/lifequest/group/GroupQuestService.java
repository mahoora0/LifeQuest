package com.lifequest.group;
import com.lifequest.common.exception.*;
import com.lifequest.group.dto.*;
import com.lifequest.user.UserRepository;
import java.time.*;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
@Service
public class GroupQuestService {
    private final GroupRepository groups;private final GroupMemberRepository members;private final GroupQuestRepository quests;private final UserRepository users;private final Clock clock;
    public GroupQuestService(GroupRepository groups,GroupMemberRepository members,GroupQuestRepository quests,UserRepository users,Clock clock){this.groups=groups;this.members=members;this.quests=quests;this.users=users;this.clock=clock;}
    @Transactional(readOnly=true) public PagedResponse<GroupQuestResponse> list(Long groupId,Long userId,GroupQuestScope scope,int page,int size){requireMember(groupId,userId);validatePage(page,size);if(scope==null)throw new BusinessException(ErrorCode.VALIDATION_FAILED);var p=scope==GroupQuestScope.UPCOMING?quests.findUpcoming(groupId,now(),PageRequest.of(page,size)):quests.findPast(groupId,now(),PageRequest.of(page,size));return PagedResponse.from(p,GroupQuestResponse::from);}
    @Transactional(readOnly=true) public GroupQuestResponse detail(Long groupId,Long userId,Long questId){requireMember(groupId,userId);return GroupQuestResponse.from(find(groupId,questId));}
    @Transactional public GroupQuestResponse create(Long groupId,Long userId,CreateGroupQuestRequest r){Group group=owner(groupId,userId);LocalDateTime now=now();validateSchedule(r.scheduledAt(),now);return GroupQuestResponse.from(quests.save(new GroupQuest(group,users.findById(userId).orElseThrow(),text(r.title(),2,100),text(r.description(),1,1000),text(r.placeName(),1,200),r.scheduledAt(),now)));}
    @Transactional public GroupQuestResponse update(Long groupId,Long userId,Long questId,UpdateGroupQuestRequest r){owner(groupId,userId);GroupQuest q=find(groupId,questId);LocalDateTime now=now();modifiable(q,now);validateSchedule(r.scheduledAt(),now);q.update(text(r.title(),2,100),text(r.description(),1,1000),text(r.placeName(),1,200),r.scheduledAt(),now);return GroupQuestResponse.from(q);}
    @Transactional public GroupQuestResponse cancel(Long groupId,Long userId,Long questId){owner(groupId,userId);GroupQuest q=find(groupId,questId);LocalDateTime now=now();modifiable(q,now);q.cancel(now);return GroupQuestResponse.from(q);}
    private Group owner(Long id,Long userId){Group g=groups.findById(id).orElseThrow(()->new BusinessException(ErrorCode.GROUP_NOT_FOUND));if(g.getStatus()!=GroupStatus.ACTIVE)throw new BusinessException(ErrorCode.GROUP_ARCHIVED);if(!g.getOwner().getId().equals(userId))throw new BusinessException(ErrorCode.GROUP_OWNER_REQUIRED);return g;}
    private void requireMember(Long id,Long userId){if(members.findByGroupIdAndUserId(id,userId).filter(m->m.getStatus()==GroupMemberStatus.ACTIVE).isEmpty())throw new BusinessException(ErrorCode.GROUP_ACCESS_DENIED);}
    private GroupQuest find(Long groupId,Long id){return quests.findByIdAndGroupId(id,groupId).orElseThrow(()->new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));}
    private void modifiable(GroupQuest q,LocalDateTime now){if(q.getStatus()==GroupQuestStatus.CANCELLED)throw new BusinessException(ErrorCode.GROUP_QUEST_CANCELLED);if(!q.getScheduledAt().isAfter(now))throw new BusinessException(ErrorCode.GROUP_QUEST_ALREADY_STARTED);}
    private void validateSchedule(LocalDateTime value,LocalDateTime now){if(value==null||!value.isAfter(now))throw new BusinessException(ErrorCode.VALIDATION_FAILED);}
    private String text(String v,int min,int max){String s=v==null?"":v.trim();if(s.length()<min||s.length()>max)throw new BusinessException(ErrorCode.VALIDATION_FAILED);return s;}
    private LocalDateTime now(){return LocalDateTime.now(clock);}private void validatePage(int page,int size){if(page<0||size<1||size>50)throw new BusinessException(ErrorCode.VALIDATION_FAILED);}
}
