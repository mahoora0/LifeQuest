package com.lifequest.group;

import com.lifequest.user.User;
import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "quest_groups")
public class Group {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "owner_user_id")
    private User owner;
    @Column(nullable = false, length = 100) private String name;
    @Column(nullable = false, length = 500) private String description;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20)
    private GroupVisibility visibility;
    @Column(name = "max_members", nullable = false) private int maxMembers;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20)
    private GroupStatus status;
    @Column(name = "created_at", nullable = false, updatable = false) private LocalDateTime createdAt;
    @Column(name = "updated_at", nullable = false) private LocalDateTime updatedAt;

    protected Group() {}
    public Group(User owner, String name, String description, GroupVisibility visibility, int maxMembers, LocalDateTime now) {
        this.owner = owner; this.name = name; this.description = description;
        this.visibility = visibility; this.maxMembers = maxMembers; this.status = GroupStatus.ACTIVE;
        this.createdAt = now; this.updatedAt = now;
    }
    public void update(String name, String description, GroupVisibility visibility, int maxMembers, LocalDateTime now) {
        this.name = name; this.description = description; this.visibility = visibility;
        this.maxMembers = maxMembers; this.updatedAt = now;
    }
    public void transferOwner(User owner, LocalDateTime now) { this.owner = owner; this.updatedAt = now; }
    public void archive(LocalDateTime now) { this.status = GroupStatus.ARCHIVED; this.updatedAt = now; }
    public Long getId() { return id; }
    public User getOwner() { return owner; }
    public String getName() { return name; }
    public String getDescription() { return description; }
    public GroupVisibility getVisibility() { return visibility; }
    public int getMaxMembers() { return maxMembers; }
    public GroupStatus getStatus() { return status; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
}
