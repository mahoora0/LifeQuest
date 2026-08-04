package com.lifequest.social;

import com.lifequest.user.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import java.util.Objects;

// 친구 관계를 나타내는 엔티티
@Entity
@Table(name = "friendships", uniqueConstraints = @UniqueConstraint(name = "uk_friendships_user_friend", columnNames = {
        "user_id", "friend_id" }), indexes = @Index(name = "idx_friendships_friend", columnList = "friend_id"))
public class Friendship {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "friend_id", nullable = false)
    private User friend;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected Friendship() {
    }

    public Friendship(User user, User friend) {
        this.user = Objects.requireNonNull(user, "사용자는 필수입니다");
        this.friend = Objects.requireNonNull(friend, "친구는 필수입니다");
        validateDifferentUsers(user, friend);
    }

    @PrePersist
    void prePersist() {
        createdAt = Instant.now();
    }

    private static void validateDifferentUsers(User user, User friend) {
        if (user == friend
                || user.getId() != null && user.getId().equals(friend.getId())) {
            throw new IllegalArgumentException("자기 자신과 친구 관계를 만들 수 없습니다");
        }
    }

    public Long getId() {
        return id;
    }

    public User getUser() {
        return user;
    }

    public User getFriend() {
        return friend;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
