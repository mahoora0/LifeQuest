package com.lifequest.growth;

import com.lifequest.user.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "exp_logs")
public class ExpLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "source_type", nullable = false, length = 30)
    private String sourceType;

    @Column(name = "source_id", nullable = false)
    private Long sourceId;

    @Column(name = "exp_amount", nullable = false)
    private int expAmount;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected ExpLog() {
    }

    public ExpLog(User user, String sourceType, Long sourceId, int expAmount) {
        this.user = user;
        this.sourceType = sourceType;
        this.sourceId = sourceId;
        this.expAmount = expAmount;
        this.createdAt = Instant.now();
    }

    public Long getId() { return id; }
    public User getUser() { return user; }
    public String getSourceType() { return sourceType; }
    public Long getSourceId() { return sourceId; }
    public int getExpAmount() { return expAmount; }
    public Instant getCreatedAt() { return createdAt; }
}
