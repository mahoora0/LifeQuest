package com.lifequest.quest.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 완료·위치 인증 기록(QUEST_COMPLETIONS).
 *
 * <p>{@code user_daily_quest_id}의 UNIQUE 제약이 완료 멱등성의 DB 레벨 근거다 — 하나의 배정 건은
 * 완료 기록을 하나만 가지므로 동일 요청이 반복돼도 중복 생성이 차단된다. 위치 항목
 * ({@code verifiedLatitude}·{@code verifiedLongitude}·{@code distanceM}·{@code accuracyM})은
 * LOCATION 완료에만 채워지고 SELF_REPORT 완료에는 null이다.
 */
@Entity
@Table(
        name = "quest_completions",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_quest_completions_udq",
                columnNames = "user_daily_quest_id"))
public class QuestCompletion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_daily_quest_id", nullable = false)
    private Long userDailyQuestId;

    /** USERS.id 참조(팀원1, 조회 편의 비정규화). 테이블 미존재로 FK 제약은 후속 마이그레이션에서 추가한다. */
    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "quest_id", nullable = false)
    private Long questId;

    @Column(name = "verified_latitude", precision = 10, scale = 7)
    private BigDecimal verifiedLatitude;

    @Column(name = "verified_longitude", precision = 10, scale = 7)
    private BigDecimal verifiedLongitude;

    @Column(name = "distance_m", precision = 8, scale = 2)
    private BigDecimal distanceM;

    @Column(name = "accuracy_m", precision = 8, scale = 2)
    private BigDecimal accuracyM;

    @Column(name = "completed_at", nullable = false)
    private LocalDateTime completedAt;

    protected QuestCompletion() {
    }

    public QuestCompletion(Long userDailyQuestId, Long userId, Long questId,
                           BigDecimal verifiedLatitude, BigDecimal verifiedLongitude,
                           BigDecimal distanceM, BigDecimal accuracyM, LocalDateTime completedAt) {
        this.userDailyQuestId = userDailyQuestId;
        this.userId = userId;
        this.questId = questId;
        this.verifiedLatitude = verifiedLatitude;
        this.verifiedLongitude = verifiedLongitude;
        this.distanceM = distanceM;
        this.accuracyM = accuracyM;
        this.completedAt = completedAt;
    }

    public Long getId() {
        return id;
    }

    public Long getUserDailyQuestId() {
        return userDailyQuestId;
    }

    public Long getUserId() {
        return userId;
    }

    public Long getQuestId() {
        return questId;
    }

    public BigDecimal getVerifiedLatitude() {
        return verifiedLatitude;
    }

    public BigDecimal getVerifiedLongitude() {
        return verifiedLongitude;
    }

    public BigDecimal getDistanceM() {
        return distanceM;
    }

    public BigDecimal getAccuracyM() {
        return accuracyM;
    }

    public LocalDateTime getCompletedAt() {
        return completedAt;
    }
}
