package com.lifequest.quest.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 주간 AI 슬롯을 썼다는 기록(WEEKLY_AI_QUEST_CLAIMS).
 *
 * <h2>제약 두 개가 서로 다른 것을 지킨다</h2>
 * <ul>
 *   <li>{@code uk_weekly_ai_claim_period(user_id, period_start)} — 한 사용자가 한 주에 하나만 고른다
 *   <li>{@code uk_weekly_ai_claim_candidate(candidate_id)} — 하나의 후보는 정확히 한 번만 소비된다
 * </ul>
 *
 * <p>두 번째를 {@code candidates.claimed_at}으로 대신하지 않는다. claimed_at은 애플리케이션이
 * 읽고 쓰는 상태라 조회와 갱신 사이에 창이 있고, UNIQUE는 DB 불변식이라 동시 요청에도 창이 없다.
 * 둘을 함께 두는 것은 중복이 아니라 층이 다른 것이다.
 *
 * <h2>왜 이 기록이 quests가 아니라 별도 테이블인가</h2>
 * {@code QUESTS}는 배정·완료가 참조하는 <b>원본 정의</b>다. "이번 주에 슬롯을 썼는가"는 정의가
 * 아니라 선택 이력이라 거기 두면 역할이 섞인다. 분리해 두면 퀘스트가 비활성화되거나 사라져도
 * 같은 주에 다시 받는 것을 계속 막을 수 있다.
 *
 * <h2>quest_id·user_daily_quest_id를 두지 않는다</h2>
 * 선택된 AI 퀘스트는 {@code quests.owner_user_id}와 {@code user_daily_quests.assigned_date}로
 * 찾을 수 있어 파생 가능하다. 비워 두면 이 행을 <b>트랜잭션 맨 앞에서</b> INSERT할 수 있고,
 * 그래야 V19가 마커에 대해 적은 대로 판정을 조회가 아니라 제약 위반으로 할 수 있다.
 *
 * <p>대신 재시도 멱등성은 포기한다 — 서버는 성공했는데 응답이 끊겨 앱이 같은 요청을 다시 보내면
 * 409를 받는다. 앱이 목록을 새로 부르면 자기 퀘스트가 거기 있으므로 지금은 이것으로 충분하다.
 */
@Entity
@Table(
    name = "weekly_ai_quest_claims",
    uniqueConstraints = {
        @UniqueConstraint(name = "uk_weekly_ai_claim_period", columnNames = {"user_id", "period_start"}),
        @UniqueConstraint(name = "uk_weekly_ai_claim_candidate", columnNames = {"candidate_id"})
    })
public class WeeklyAiQuestClaim {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    /** 그 주 월요일(논리적 일자). {@code user_daily_quests.assigned_date}와 같은 값이다. */
    @Column(name = "period_start", nullable = false)
    private LocalDate periodStart;

    @Column(name = "candidate_id", nullable = false)
    private Long candidateId;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    protected WeeklyAiQuestClaim() {
    }

    public WeeklyAiQuestClaim(Long userId, LocalDate periodStart, Long candidateId, LocalDateTime now) {
        this.userId = userId;
        this.periodStart = periodStart;
        this.candidateId = candidateId;
        this.createdAt = now;
    }

    public Long getId() {
        return id;
    }

    public Long getUserId() {
        return userId;
    }

    public LocalDate getPeriodStart() {
        return periodStart;
    }

    public Long getCandidateId() {
        return candidateId;
    }
}
