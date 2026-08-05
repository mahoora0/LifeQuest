package com.lifequest.group.dto;
import com.lifequest.group.GroupChatMessage;
import java.time.LocalDateTime;
public record GroupMessageResponse(Long id,Long senderUserId,String senderNickname,String content,boolean mine,LocalDateTime createdAt) {
    public static GroupMessageResponse from(GroupChatMessage m,Long userId){return new GroupMessageResponse(m.getId(),m.getSender().getId(),m.getSender().getNickname(),m.getContent(),m.getSender().getId().equals(userId),m.getCreatedAt());}
}
