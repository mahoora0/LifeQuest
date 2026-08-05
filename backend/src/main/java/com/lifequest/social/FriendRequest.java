package com.lifequest.social;

import com.lifequest.user.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.Objects;

// 친구 요청을 나타내는 엔티티
@Entity
@Table(name = "friend_requests", indexes = {
        @Index(name = "idx_friend_requests_receiver_status", columnList = "receiver_id,status"),
        @Index(name = "idx_friend_requests_sender_receiver_status", columnList = "sender_id,receiver_id,status")
})
public class FriendRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "sender_id", nullable = false)
    private User sender;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "receiver_id", nullable = false)
    private User receiver;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private FriendRequestStatus status;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "responded_at")
    private Instant respondedAt;

    protected FriendRequest() {
    }

    public FriendRequest(User sender, User receiver) {
        this.sender = Objects.requireNonNull(sender, "요청자는 필수입니다");
        this.receiver = Objects.requireNonNull(receiver, "수신자는 필수입니다");
        validateDifferentUsers(sender, receiver);
        this.status = FriendRequestStatus.PENDING;
    }

    @PrePersist
    void prePersist() {
        createdAt = Instant.now();
    }

    public void accept() {
        respond(FriendRequestStatus.ACCEPTED);
    }

    public void reject() {
        respond(FriendRequestStatus.REJECTED);
    }

    public void cancel() {
        respond(FriendRequestStatus.CANCELLED);
    }

    private void respond(FriendRequestStatus nextStatus) {
        if (status != FriendRequestStatus.PENDING) {
            throw new IllegalStateException("대기 중인 친구 요청만 처리할 수 있습니다");
        }
        status = nextStatus;
        respondedAt = Instant.now();
    }

    private static void validateDifferentUsers(User sender, User receiver) {
        if (sender == receiver
                || sender.getId() != null && sender.getId().equals(receiver.getId())) {
            throw new IllegalArgumentException("자기 자신에게 친구 요청을 보낼 수 없습니다");
        }
    }

    public Long getId() {
        return id;
    }

    public User getSender() {
        return sender;
    }

    public User getReceiver() {
        return receiver;
    }

    public FriendRequestStatus getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getRespondedAt() {
        return respondedAt;
    }
}
