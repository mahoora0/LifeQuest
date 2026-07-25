package com.lifequest.profile;

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
@Table(name = "user_titles")
public class UserTitle {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "title_id", nullable = false)
    private Title title;

    @Column(name = "source_type", nullable = false, length = 30)
    private String sourceType;

    @Column(name = "source_id", nullable = false)
    private Long sourceId;

    @Column(name = "acquired_at", nullable = false)
    private Instant acquiredAt;

    protected UserTitle() {
    }

    public UserTitle(User user, Title title, String sourceType, Long sourceId) {
        this.user = user;
        this.title = title;
        this.sourceType = sourceType;
        this.sourceId = sourceId;
        this.acquiredAt = Instant.now();
    }

    public Title getTitle() {
        return title;
    }

    public String getSourceType() {
        return sourceType;
    }

    public Long getSourceId() {
        return sourceId;
    }

    public Instant getAcquiredAt() {
        return acquiredAt;
    }
}
