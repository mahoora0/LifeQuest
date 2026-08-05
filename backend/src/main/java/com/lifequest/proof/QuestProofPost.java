package com.lifequest.proof;

import com.lifequest.quest.domain.Quest;
import com.lifequest.user.User;
import jakarta.persistence.CascadeType;
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
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * 사진 인증 게시물. 항상 하나의 퀘스트 완료 기록에서 파생된다.
 *
 * <p>{@code questCompletionId}를 생성자에서만 받고 이후 바꿀 수 없게 두는 것이 요점이다.
 * 게시물에 표시되는 퀘스트명은 사용자 입력이 아니라 이 완료 기록을 따라오므로, 사용자가
 * 실제로 하지 않은 퀘스트를 붙여 인증을 받는 경로가 생기지 않는다.
 *
 * <p>표 수를 컬럼으로 들고 있는 이유는 피드가 게시물마다 투표 테이블을 집계하지 않게 하기
 * 위해서다. 갱신은 반드시 {@link #applyVote}를 거치며, 표를 더하는 것과 상태를 다시
 * 판정하는 것을 한 메서드에 묶어 둔다 — 따로 두면 표만 늘고 상태가 안 바뀌는 조합이 생긴다.
 */
@Entity
@Table(name = "quest_proof_posts")
public class QuestProofPost {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User author;

    @Column(name = "quest_completion_id", nullable = false, updatable = false)
    private Long questCompletionId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "quest_id", nullable = false)
    private Quest quest;

    @Column(name = "content", length = 500)
    private String content;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private ProofPostStatus status = ProofPostStatus.VOTING;

    @Column(name = "agree_count", nullable = false)
    private int agreeCount;

    @Column(name = "unsure_count", nullable = false)
    private int unsureCount;

    @Column(name = "reject_count", nullable = false)
    private int rejectCount;

    @Column(name = "comment_count", nullable = false)
    private int commentCount;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    /** 사진은 게시물과 수명이 같고 피드 카드에서 항상 함께 쓰인다. */
    @OneToMany(mappedBy = "post", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("sortOrder ASC")
    private List<QuestProofPhoto> photos = new ArrayList<>();

    protected QuestProofPost() {
    }

    public QuestProofPost(User author, Long questCompletionId, Quest quest, String content, LocalDateTime now) {
        this.author = author;
        this.questCompletionId = questCompletionId;
        this.quest = quest;
        this.content = content;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public void addPhoto(String imageUrl) {
        photos.add(new QuestProofPhoto(this, imageUrl, photos.size()));
    }

    /**
     * 표를 더하고 곧바로 상태를 다시 판정한다. 반환값은 판정이 실제로 바뀌었는지 여부로,
     * 호출자가 알림 같은 후속 처리를 붙일 자리다.
     */
    public boolean applyVote(ProofVoteChoice choice, ProofSettings settings, LocalDateTime now) {
        switch (choice) {
            case AGREE -> agreeCount++;
            case UNSURE -> unsureCount++;
            case REJECT -> rejectCount++;
        }

        ProofPostStatus previous = status;
        status = ProofPostStatus.of(
                agreeCount,
                rejectCount,
                settings.minVotes(),
                settings.agreeThreshold(),
                settings.unclearFloor());
        updatedAt = now;
        return previous != status;
    }

    public void addComment(LocalDateTime now) {
        commentCount++;
        updatedAt = now;
    }

    public void removeComment(LocalDateTime now) {
        if (commentCount > 0) {
            commentCount--;
        }
        updatedAt = now;
    }

    public boolean isAuthor(Long userId) {
        return author.getId().equals(userId);
    }

    /** 판정에 쓰인 유효 표 수. UNSURE는 빠져 있어 화면의 "2/3" 표기가 이 값을 쓴다. */
    public int decidedVoteCount() {
        return agreeCount + rejectCount;
    }

    public Long getId() {
        return id;
    }

    public User getAuthor() {
        return author;
    }

    public Long getQuestCompletionId() {
        return questCompletionId;
    }

    public Quest getQuest() {
        return quest;
    }

    public String getContent() {
        return content;
    }

    public ProofPostStatus getStatus() {
        return status;
    }

    public int getAgreeCount() {
        return agreeCount;
    }

    public int getUnsureCount() {
        return unsureCount;
    }

    public int getRejectCount() {
        return rejectCount;
    }

    public int getCommentCount() {
        return commentCount;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public List<QuestProofPhoto> getPhotos() {
        return photos;
    }
}
