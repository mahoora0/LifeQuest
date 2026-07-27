package com.lifequest.quest.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * "오늘의 퀘스트" 배정 기록(USER_DAILY_QUESTS). 완료 요청은 퀘스트 원본 ID가 아니라 이 배정 ID를 대상으로 한다.
 *
 * <p>{@code UNIQUE(user_id, quest_id, assigned_date)}로 동일 퀘스트의 하루 중복 배정을 막는다.
 * 상태 전이 시점(완료/만료 판정)은 서비스 계층에서 결정한다.
 */
@Entity
@Table(
        name = "user_daily_quests",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_user_daily_quests",
                columnNames = {"user_id", "quest_id", "assigned_date"}))
public class UserDailyQuest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * USERS.id 참조(팀원1 소유). 크로스도메인 FK는 팀원1 테이블에 제약을 발생시켜 퀘스트 도메인
     * 담당(팀원2)이 단독으로 결정할 사안이 아니다 — BIGINT 컬럼으로만 둔다. 배정 단위 정합성은
     * {@code uk_user_daily_quests}가 잡는다.
     */
    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "quest_id", nullable = false)
    private Long questId;

    @Column(name = "assigned_date", nullable = false)
    private LocalDate assignedDate;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private DailyQuestStatus status;

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    protected UserDailyQuest() {
    }

    public UserDailyQuest(Long userId, Long questId, LocalDate assignedDate, LocalDateTime expiresAt) {
        this.userId = userId;
        this.questId = questId;
        this.assignedDate = assignedDate;
        this.expiresAt = expiresAt;
        this.status = DailyQuestStatus.ASSIGNED;
    }

    public Long getId() {
        return id;
    }

    public Long getUserId() {
        return userId;
    }

    public Long getQuestId() {
        return questId;
    }

    public LocalDate getAssignedDate() {
        return assignedDate;
    }

    public DailyQuestStatus getStatus() {
        return status;
    }

    public LocalDateTime getExpiresAt() {
        return expiresAt;
    }

    public void markCompleted() {
        this.status = DailyQuestStatus.COMPLETED;
    }

    public void markExpired() {
        this.status = DailyQuestStatus.EXPIRED;
    }
}
