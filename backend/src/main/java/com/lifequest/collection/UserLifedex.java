package com.lifequest.collection;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.LocalDateTime;

@Entity
@Table(name = "user_lifedex")
class UserLifedex {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "lifedex_item_id", nullable = false)
    private Long lifedexItemId;

    @Column(name = "collected_at", nullable = false)
    private LocalDateTime collectedAt;

    protected UserLifedex() {
    }

    UserLifedex(Long userId, Long lifedexItemId) {
        this.userId = userId;
        this.lifedexItemId = lifedexItemId;
    }

    @PrePersist
    void onCreate() {
        if (collectedAt == null) {
            collectedAt = LocalDateTime.now();
        }
    }

    Long getLifedexItemId() {
        return lifedexItemId;
    }
}
