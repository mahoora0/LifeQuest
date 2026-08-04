package com.lifequest.group;
import com.lifequest.user.User;
import jakarta.persistence.*;
import java.time.LocalDateTime;
@Entity @Table(name = "group_chat_messages")
public class GroupChatMessage {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "group_id") private Group group;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "sender_user_id") private User sender;
    @Column(nullable = false, length = 1000) private String content;
    @Column(name = "created_at", nullable = false, updatable = false) private LocalDateTime createdAt;
    protected GroupChatMessage() {}
    public GroupChatMessage(Group group, User sender, String content, LocalDateTime createdAt) { this.group=group; this.sender=sender; this.content=content; this.createdAt=createdAt; }
    public Long getId(){return id;} public Group getGroup(){return group;} public User getSender(){return sender;} public String getContent(){return content;} public LocalDateTime getCreatedAt(){return createdAt;}
}
