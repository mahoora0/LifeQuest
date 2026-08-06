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
 * 배정 생성 마커(QUEST_ASSIGNMENT_MARKERS). 한 사용자의 한 트랙·한 주기에 정확히 한 행이 존재한다.
 *
 * <p>배정은 지연 생성이다 — 조회가 해당 주기의 배정을 찾지 못하면 그 자리에서 만든다. 그래서 같은
 * 사용자의 동시 요청이 모두 "배정 없음"을 보고 각각 생성을 시도할 수 있고,
 * {@code uk_user_daily_quests(user_id, quest_id, assigned_date)}는 이를 막지 못한다. 두 요청이 서로 다른
 * 퀘스트를 뽑으면 겹치는 행이 없어 제약에 걸리지 않고, 한 트랙에 6개가 배정되어 슬롯 계약이 깨진다.
 *
 * <p>생성 트랜잭션은 이 마커를 <b>가장 먼저</b> 저장한다. 유니크 위반이 나면 다른 요청이 이미 만든
 * 것이므로 생성을 포기하고 재조회로 돌아간다. 판정 주체가 애플리케이션 조회가 아니라 DB 제약이라
 * 인스턴스를 늘려도 무력화되지 않는다 — 애플리케이션 레벨 락은 이 성질을 갖지 못한다.
 *
 * <p>이 엔티티는 상태를 갖지 않는다. 존재 자체가 "이 주기의 배정은 이미 만들어졌다"는 사실이며,
 * 배정 내용은 {@link UserDailyQuest}가 들고 있다.
 */
@Entity
@Table(
        name = "quest_assignment_markers",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_quest_assignment_markers",
                columnNames = {"user_id", "cadence", "period_start"}))
public class QuestAssignmentMarker {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * USERS.id 참조(팀원 1 소유). {@link UserDailyQuest}와 같은 이유로 FK를 걸지 않는다 —
     * 크로스도메인 FK는 타 담당 테이블에 제약을 만들어 퀘스트 도메인 담당이 단독으로 정할 사안이 아니다.
     */
    @Column(name = "user_id", nullable = false)
    private Long userId;

    /** 트랙. 갱신 주기가 트랙마다 달라 키에 포함한다 — 일간은 매일, 주간은 매주 월요일에 새 행이 생긴다. */
    @Enumerated(EnumType.STRING)
    @Column(name = "cadence", nullable = false, length = 20)
    private QuestCadence cadence;

    /** 주기 시작일. {@code UserDailyQuest.assignedDate}와 같은 값이다(docs/05-business-rules.md §1-2). */
    @Column(name = "period_start", nullable = false)
    private LocalDate periodStart;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    protected QuestAssignmentMarker() {
    }

    public QuestAssignmentMarker(Long userId, QuestCadence cadence, LocalDate periodStart,
                                 LocalDateTime createdAt) {
        this.userId = userId;
        this.cadence = cadence;
        this.periodStart = periodStart;
        this.createdAt = createdAt;
    }

    public Long getId() {
        return id;
    }

    public Long getUserId() {
        return userId;
    }

    public QuestCadence getCadence() {
        return cadence;
    }

    public LocalDate getPeriodStart() {
        return periodStart;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }
}