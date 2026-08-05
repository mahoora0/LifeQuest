package com.lifequest.proof;

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
import java.time.LocalDateTime;

/**
 * 인증 게시물의 댓글. EXP를 주지 않는다 — 주는 순간 도배 방지 로직이 필요해지고,
 * 그 로직이 이 기능에서 제일 큰 덩어리가 된다.
 */
@Entity
@Table(name = "quest_proof_comments")
public class QuestProofComment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "post_id", nullable = false)
    private QuestProofPost post;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "author_user_id", nullable = false)
    private User author;

    @Column(name = "content", nullable = false, length = 500)
    private String content;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    protected QuestProofComment() {
    }

    public QuestProofComment(QuestProofPost post, User author, String content, LocalDateTime now) {
        this.post = post;
        this.author = author;
        this.content = content;
        this.createdAt = now;
    }

    public boolean isAuthor(Long userId) {
        return author.getId().equals(userId);
    }

    public Long getId() {
        return id;
    }

    public User getAuthor() {
        return author;
    }

    public String getContent() {
        return content;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }
}
