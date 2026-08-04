package com.lifequest.group;
import com.lifequest.common.exception.*;
import com.lifequest.group.dto.*;
import com.lifequest.user.*;
import java.time.*;
import java.util.*;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
@Service
public class GroupChatService {
    private final GroupRepository groups;private final GroupMemberRepository members;private final GroupChatMessageRepository messages;private final UserRepository users;private final Clock clock;
    public GroupChatService(GroupRepository groups,GroupMemberRepository members,GroupChatMessageRepository messages,UserRepository users,Clock clock){this.groups=groups;this.members=members;this.messages=messages;this.users=users;this.clock=clock;}
    @Transactional(readOnly=true) public GroupMessagePageResponse get(Long groupId,Long userId,Long beforeId,Long afterId,int size){
        requireMember(groupId,userId);if(beforeId!=null&&afterId!=null||size<1||size>50)throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        List<GroupChatMessage> found;if(beforeId!=null)found=messages.findBefore(groupId,beforeId,PageRequest.of(0,size));else if(afterId!=null)found=messages.findAfter(groupId,afterId,PageRequest.of(0,size));else found=messages.findLatest(groupId,PageRequest.of(0,size));
        if(afterId==null)Collections.reverse(found);List<GroupMessageResponse> result=found.stream().map(m->GroupMessageResponse.from(m,userId)).toList();Long latest=result.isEmpty()?afterId:result.get(result.size()-1).id();Long first=result.isEmpty()?beforeId:result.get(0).id();
        // 폴링(afterId) 호출자는 그 앞을 이미 갖고 있어 hasMoreBefore가 항상 참이 되므로 제외한다.
        boolean more=afterId==null&&first!=null&&messages.existsByGroupIdAndIdLessThan(groupId,first);return new GroupMessagePageResponse(result,more,latest);
    }
    @Transactional public GroupMessageResponse send(Long groupId,Long userId,String raw){Group group=groups.findById(groupId).orElseThrow(()->new BusinessException(ErrorCode.GROUP_NOT_FOUND));if(group.getStatus()!=GroupStatus.ACTIVE)throw new BusinessException(ErrorCode.GROUP_ARCHIVED);requireMember(groupId,userId);String content=raw==null?"":raw.trim();if(content.isEmpty()||content.length()>1000)throw new BusinessException(ErrorCode.VALIDATION_FAILED);GroupChatMessage saved=messages.save(new GroupChatMessage(group,users.findById(userId).orElseThrow(),content,LocalDateTime.now(clock)));return GroupMessageResponse.from(saved,userId);}
    private void requireMember(Long groupId,Long userId){if(members.findByGroupIdAndUserId(groupId,userId).filter(m->m.getStatus()==GroupMemberStatus.ACTIVE).isEmpty())throw new BusinessException(ErrorCode.GROUP_ACCESS_DENIED);}
}
