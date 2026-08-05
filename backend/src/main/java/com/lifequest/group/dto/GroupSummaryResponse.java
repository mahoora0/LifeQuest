package com.lifequest.group.dto;
import com.lifequest.group.*;
public record GroupSummaryResponse(Long groupId,String name,String description,int activeMemberCount,int maxMembers,boolean joinable,GroupMemberRole myRole,GroupMemberStatus myMembershipStatus,GroupStatus status) {}
