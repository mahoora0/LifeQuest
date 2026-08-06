package com.lifequest.proof;

import com.lifequest.user.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.LocalDateTime;

/**
 * 한 사용자가 한 게시물에 던진 표. 수정 메서드가 없는 것이 의도다 —
 * 번복을 허용하면 게시물의 표 카운터를 되돌리고 이미 지급한 EXP를 회수하는 경로가
 * 필요해지는데, 그 복잡도에 값하는 기능이 아니다. 재투표는 {@code UNIQUE(post_id,
 * voter_user_id)}에서 막힌다.
 */
@Entity
@Table(name = "quest_proof_votes")
public class QuestProofVote {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "post_id", nullable = false)
    private QuestProofPost post;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "voter_user_id", nullable = false)
    private User voter;

    @Enumerated(EnumType.STRING)
    @Column(name = "choice", nullable = false, length = 20)
    private ProofVoteChoice choice;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    protected QuestProofVote() {
    }

    public QuestProofVote(QuestProofPost post, User voter, ProofVoteChoice choice, LocalDateTime now) {
        this.post = post;
        this.voter = voter;
        this.choice = choice;
        this.createdAt = now;
    }

    public Long getId() {
        return id;
    }

    /** 지연 로딩 프록시의 식별자만 읽으므로 게시물 초기화를 유발하지 않는다. */
    public Long getPostId() {
        return post.getId();
    }

    public ProofVoteChoice getChoice() {
        return choice;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }
}
