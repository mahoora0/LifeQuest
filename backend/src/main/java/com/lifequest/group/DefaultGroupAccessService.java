package com.lifequest.group;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class DefaultGroupAccessService implements GroupAccessService {
    private final GroupRepository groups;
    private final GroupMemberRepository members;
    public DefaultGroupAccessService(GroupRepository groups, GroupMemberRepository members){this.groups=groups;this.members=members;}
    @Override @Transactional(readOnly=true) public void requireActiveGroup(Long groupId){
        Group group=groups.findById(groupId).orElseThrow(()->new BusinessException(ErrorCode.GROUP_NOT_FOUND));
        if(group.getStatus()!=GroupStatus.ACTIVE) throw new BusinessException(ErrorCode.GROUP_ARCHIVED);
    }
    @Override @Transactional(readOnly=true) public void requireActiveMember(Long groupId,Long userId){
        if(!isActiveMember(groupId,userId)) throw new BusinessException(ErrorCode.GROUP_ACCESS_DENIED);
    }
    @Override @Transactional(readOnly=true) public void requireOwner(Long groupId,Long userId){
        Group group=groups.findById(groupId).orElseThrow(()->new BusinessException(ErrorCode.GROUP_NOT_FOUND));
        if(!group.getOwner().getId().equals(userId)) throw new BusinessException(ErrorCode.GROUP_OWNER_REQUIRED);
    }
    @Override @Transactional(readOnly=true) public boolean isActiveMember(Long groupId,Long userId){
        return members.findByGroupIdAndUserId(groupId,userId).filter(m->m.getStatus()==GroupMemberStatus.ACTIVE).isPresent();
    }
    @Override @Transactional(readOnly=true) public List<Long> getActiveMemberIds(Long groupId){
        return members.findByGroupIdAndStatusOrderByIdAsc(groupId,GroupMemberStatus.ACTIVE,Pageable.unpaged()).stream().map(m->m.getUser().getId()).toList();
    }
}
