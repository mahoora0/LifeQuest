package com.lifequest.group.dto;
import com.lifequest.group.*;
import java.time.LocalDateTime;
public record GroupMemberResponse(Long memberId,Long groupId,String groupName,Long userId,String nickname,GroupMemberRole role,GroupMemberStatus status,LocalDateTime expiresAt,LocalDateTime joinedAt) {
    public static GroupMemberResponse from(GroupMember m){return new GroupMemberResponse(m.getId(),m.getGroup().getId(),m.getGroup().getName(),m.getUser().getId(),m.getUser().getNickname(),m.getRole(),m.getStatus(),m.getExpiresAt(),m.getJoinedAt());}
}
