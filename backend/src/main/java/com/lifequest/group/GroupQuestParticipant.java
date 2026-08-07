package com.lifequest.group;

import com.lifequest.user.User;
import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(
    name = "group_quest_participants",
    uniqueConstraints = @UniqueConstraint(
        name = "uk_group_quest_participants_quest_user",
        columnNames = {"group_quest_id", "user_id"}))
public class GroupQuestParticipant {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "group_quest_id", nullable = false)
    private GroupQuest quest;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private GroupQuestParticipationStatus status;

    @Column(name = "applied_at", nullable = false)
    private LocalDateTime appliedAt;

    @Column(name = "withdrawn_at")
    private LocalDateTime withdrawnAt;

    @Column(name = "rewarded_at")
    private LocalDateTime rewardedAt;

    protected GroupQuestParticipant() {}

    public GroupQuestParticipant(GroupQuest quest, User user, LocalDateTime now) {
        this.quest = quest;
        this.user = user;
        apply(now);
    }

    public void apply(LocalDateTime now) {
        status = GroupQuestParticipationStatus.APPLIED;
        appliedAt = now;
        withdrawnAt = null;
        rewardedAt = null;
    }

    public void withdraw(LocalDateTime now) {
        status = GroupQuestParticipationStatus.WITHDRAWN;
        withdrawnAt = now;
    }

    public void reward(LocalDateTime now) {
        status = GroupQuestParticipationStatus.REWARDED;
        rewardedAt = now;
    }

    public Long getId() { return id; }
    public GroupQuest getQuest() { return quest; }
    public User getUser() { return user; }
    public GroupQuestParticipationStatus getStatus() { return status; }
    public LocalDateTime getAppliedAt() { return appliedAt; }
    public LocalDateTime getWithdrawnAt() { return withdrawnAt; }
    public LocalDateTime getRewardedAt() { return rewardedAt; }
}
