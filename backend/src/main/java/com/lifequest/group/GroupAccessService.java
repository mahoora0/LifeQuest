package com.lifequest.group;
import java.util.List;
public interface GroupAccessService {
    void requireActiveGroup(Long groupId);
    void requireActiveMember(Long groupId, Long userId);
    void requireOwner(Long groupId, Long userId);
    boolean isActiveMember(Long groupId, Long userId);
    List<Long> getActiveMemberIds(Long groupId);
}
