package com.lifequest.group.dto;
import com.lifequest.group.*;
import java.time.LocalDateTime;
import java.util.List;
public record GroupResponse(Long id,String name,String description,GroupVisibility visibility,int maxMembers,long activeMemberCount,GroupStatus status,Long ownerUserId,String ownerNickname,GroupMemberRole myRole,GroupMemberStatus myMembershipStatus,boolean joinable,List<GroupMemberResponse> members,List<GroupQuestResponse> recentQuests,LocalDateTime createdAt,LocalDateTime updatedAt) {}
