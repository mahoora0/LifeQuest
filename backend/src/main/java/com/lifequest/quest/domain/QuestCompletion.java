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
 *
 * <p><b>불변식:</b> {@code userId}·{@code questId}는 조회 편의를 위한 비정규화 복사본이므로,
 * 반드시 배정 건({@link UserDailyQuest})에서 파생시킨다. 세 값을 따로 받으면 서비스 버그가
 * 인증된 사용자 ID를 남의 배정 건에 붙일 수 있고, 그 완료 기록이
 * {@code findByUserIdOrderByCompletedAtDescIdDesc}로 엉뚱한 사용자 이력에 나타난다.
 * 생성자가 배정 건만 받으므로 그 경로가 존재하지 않는다.
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

    /**
     * USERS.id 참조(팀원 1 소유, 조회 편의 비정규화). 크로스도메인 FK는 팀원 1 테이블에 제약을 발생시켜
     * 퀘스트 도메인 담당(팀원 2)이 단독으로 결정할 사안이 아니다 — BIGINT 컬럼으로만 두고,
     * 값 정합성은 생성자의 배정 건 파생으로 보장한다.
     */
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

    /**
     * 완료 기록은 배정 건에서만 만들어진다. {@code userId}·{@code questId}를 따로 받지 않는 것이
     * 이 생성자의 요점이다 — 클래스 주석의 불변식 참조.
     *
     * @param assignment 이미 저장된 배정 건. ID가 없으면 완료 기록이 어느 배정에 붙는지 정할 수 없다.
     */
    public QuestCompletion(UserDailyQuest assignment,
                           BigDecimal verifiedLatitude, BigDecimal verifiedLongitude,
                           BigDecimal distanceM, BigDecimal accuracyM, LocalDateTime completedAt) {
        if (assignment.getId() == null) {
            throw new IllegalArgumentException("배정 건이 먼저 저장되어야 완료 기록을 만들 수 있다");
        }
        this.userDailyQuestId = assignment.getId();
        this.userId = assignment.getUserId();
        this.questId = assignment.getQuestId();
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
