package com.lifequest.group;

import com.lifequest.user.User;
import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "group_members", uniqueConstraints = @UniqueConstraint(name = "uk_group_members_group_user", columnNames = {"group_id", "user_id"}))
public class GroupMember {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "group_id") private Group group;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "user_id") private User user;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20) private GroupMemberRole role;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 30) private GroupMemberStatus status;
    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "invited_by_user_id") private User invitedBy;
    @Column(name = "expires_at") private LocalDateTime expiresAt;
    @Column(name = "responded_at") private LocalDateTime respondedAt;
    @Column(name = "joined_at") private LocalDateTime joinedAt;
    @Column(name = "created_at", nullable = false, updatable = false) private LocalDateTime createdAt;
    @Column(name = "updated_at", nullable = false) private LocalDateTime updatedAt;

    protected GroupMember() {}
    private GroupMember(Group group, User user, GroupMemberRole role, GroupMemberStatus status, LocalDateTime now) {
        this.group = group; this.user = user; this.role = role; this.status = status;
        this.createdAt = now; this.updatedAt = now;
        if (status == GroupMemberStatus.ACTIVE) this.joinedAt = now;
    }
    public static GroupMember owner(Group group, User user, LocalDateTime now) { return new GroupMember(group, user, GroupMemberRole.OWNER, GroupMemberStatus.ACTIVE, now); }
    public static GroupMember joinRequest(Group group, User user, LocalDateTime now) { return new GroupMember(group, user, GroupMemberRole.MEMBER, GroupMemberStatus.PENDING_APPROVAL, now); }
    public static GroupMember invitation(Group group, User user, User inviter, LocalDateTime now) {
        GroupMember m = new GroupMember(group, user, GroupMemberRole.MEMBER, GroupMemberStatus.INVITED, now);
        m.invitedBy = inviter; m.expiresAt = now.plusDays(7); return m;
    }
    public void invite(User inviter, LocalDateTime now) { role = GroupMemberRole.MEMBER; status = GroupMemberStatus.INVITED; invitedBy = inviter; expiresAt = now.plusDays(7); respondedAt = null; joinedAt = null; updatedAt = now; }
    public void requestJoin(LocalDateTime now) { role = GroupMemberRole.MEMBER; status = GroupMemberStatus.PENDING_APPROVAL; invitedBy = null; expiresAt = null; respondedAt = null; joinedAt = null; updatedAt = now; }
    public void activate(LocalDateTime now) { status = GroupMemberStatus.ACTIVE; expiresAt = null; respondedAt = now; joinedAt = now; updatedAt = now; }
    public void reject(LocalDateTime now) { status = GroupMemberStatus.REJECTED; expiresAt = null; respondedAt = now; updatedAt = now; }
    public void leave(LocalDateTime now) { status = GroupMemberStatus.LEFT; respondedAt = now; updatedAt = now; }
    public void remove(LocalDateTime now) { status = GroupMemberStatus.REMOVED; respondedAt = now; updatedAt = now; }
    public void changeRole(GroupMemberRole role, LocalDateTime now) { this.role = role; this.updatedAt = now; }
    public boolean isInvitationExpired(LocalDateTime now) { return status == GroupMemberStatus.INVITED && expiresAt != null && !expiresAt.isAfter(now); }
    public Long getId() { return id; }
    public Group getGroup() { return group; }
    public User getUser() { return user; }
    public GroupMemberRole getRole() { return role; }
    public GroupMemberStatus getStatus() { return status; }
    public User getInvitedBy() { return invitedBy; }
    public LocalDateTime getExpiresAt() { return expiresAt; }
    public LocalDateTime getRespondedAt() { return respondedAt; }
    public LocalDateTime getJoinedAt() { return joinedAt; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
}
