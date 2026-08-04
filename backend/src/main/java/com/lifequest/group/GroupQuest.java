package com.lifequest.group;
import com.lifequest.user.User;
import jakarta.persistence.*;
import java.time.LocalDateTime;
@Entity @Table(name = "group_quests")
public class GroupQuest {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "group_id") private Group group;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "created_by_user_id") private User createdBy;
    @Column(nullable=false,length=100) private String title;
    @Column(nullable=false,length=1000) private String description;
    @Column(name="place_name",nullable=false,length=200) private String placeName;
    @Column(name="scheduled_at",nullable=false) private LocalDateTime scheduledAt;
    @Enumerated(EnumType.STRING) @Column(nullable=false,length=20) private GroupQuestStatus status;
    @Column(name="created_at",nullable=false,updatable=false) private LocalDateTime createdAt;
    @Column(name="updated_at",nullable=false) private LocalDateTime updatedAt;
    protected GroupQuest() {}
    public GroupQuest(Group group,User createdBy,String title,String description,String placeName,LocalDateTime scheduledAt,LocalDateTime now){this.group=group;this.createdBy=createdBy;this.title=title;this.description=description;this.placeName=placeName;this.scheduledAt=scheduledAt;this.status=GroupQuestStatus.PUBLISHED;this.createdAt=now;this.updatedAt=now;}
    public void update(String title,String description,String placeName,LocalDateTime scheduledAt,LocalDateTime now){this.title=title;this.description=description;this.placeName=placeName;this.scheduledAt=scheduledAt;this.updatedAt=now;}
    public void cancel(LocalDateTime now){status=GroupQuestStatus.CANCELLED;updatedAt=now;}
    public Long getId(){return id;} public Group getGroup(){return group;} public User getCreatedBy(){return createdBy;} public String getTitle(){return title;} public String getDescription(){return description;} public String getPlaceName(){return placeName;} public LocalDateTime getScheduledAt(){return scheduledAt;} public GroupQuestStatus getStatus(){return status;} public LocalDateTime getCreatedAt(){return createdAt;} public LocalDateTime getUpdatedAt(){return updatedAt;}
}
