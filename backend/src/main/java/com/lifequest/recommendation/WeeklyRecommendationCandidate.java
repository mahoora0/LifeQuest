package com.lifequest.recommendation;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 주간 퀘스트용으로 저장된 추천 후보(QUEST_RECOMMENDATION_CANDIDATES).
 *
 * <p>{@link QuestRecommendationCandidate}(응답 record)와 이름이 비슷하지만 역할이 다르다.
 * 그쪽은 LLM 응답을 검증해 앱으로 내보내는 값이고, 이쪽은 <b>선택의 대상이 되기 위해</b>
 * 서버가 붙잡아 두는 행이다.
 *
 * <h2>왜 저장하는가</h2>
 * 저장하지 않으면 "이 후보를 받겠다"는 요청이 후보 내용을 통째로 되돌려 보내야 한다. 그러면
 * 제목·설명·완료 가이드를 앱에서 바꿔 보낼 수 있고, {@link QuestRecommendationValidator}가
 * 예산·기간·중복을 검증한 의미가 사라진다. id만 받으면 그 경로가 닫힌다.
 *
 * <p>저장은 <b>주간 추천 경로에서만</b> 한다. 일반 place/travel 추천은 지금처럼 저장하지 않는다 —
 * 구경만 하는 요청까지 쌓으면 쓰이지 않을 행으로 테이블이 채워진다.
 *
 * <h2>periodStart가 만료를 대신한다</h2>
 * 후보의 유효기간은 시각이 아니라 <b>주기</b>다. 일요일 23:00에 받은 후보를 월요일 05:00에 고르면
 * 논리적 주가 넘어가 있고(주기 경계 04:00), 그 후보는 지난주 슬롯을 위해 만들어진 것이다.
 * 주간 배정의 만료가 주기로 정의돼 있으므로 후보도 같은 기준을 쓴다.
 */
@Entity
@Table(name = "quest_recommendation_candidates")
public class WeeklyRecommendationCandidate {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** 이 후보를 받은 사용자. 다른 사용자가 id로 가져가지 못하게 막는 기준이다. */
    @Column(name = "user_id", nullable = false)
    private Long userId;

    /** 어느 주의 슬롯을 위해 만들어졌는가. 그 주 월요일(논리적 일자)이다. */
    @Column(name = "period_start", nullable = false)
    private LocalDate periodStart;

    @Enumerated(EnumType.STRING)
    @Column(name = "recommendation_type", nullable = false, length = 20)
    private RecommendationType recommendationType;

    @Column(name = "title", nullable = false, length = 100)
    private String title;

    @Column(name = "description", nullable = false, length = 500)
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(name = "category", nullable = false, length = 20)
    private RecommendationCategory category;

    @Column(name = "duration_value", nullable = false)
    private int durationValue;

    @Enumerated(EnumType.STRING)
    @Column(name = "duration_unit", nullable = false, length = 20)
    private DurationUnit durationUnit;

    @Column(name = "estimated_cost_per_person", nullable = false)
    private int estimatedCostPerPerson;

    @Column(name = "suggested_place_name", nullable = false, length = 100)
    private String suggestedPlaceName;

    @Column(name = "completion_guide", nullable = false, length = 300)
    private String completionGuide;

    /**
     * 퀘스트로 받은 시각. 같은 후보의 재사용을 막는 <b>애플리케이션 상태</b>이며, DB 불변식은
     * {@code uk_weekly_ai_claim_candidate}가 따로 진다 — 조회와 갱신 사이의 창을 제약이 닫는다.
     */
    @Column(name = "claimed_at")
    private LocalDateTime claimedAt;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    protected WeeklyRecommendationCandidate() {
    }

    public WeeklyRecommendationCandidate(Long userId, LocalDate periodStart,
                                         QuestRecommendationCandidate source, LocalDateTime now) {
        this.userId = userId;
        this.periodStart = periodStart;
        this.recommendationType = source.recommendationType();
        this.title = source.title();
        this.description = source.description();
        this.category = source.category();
        this.durationValue = source.durationValue();
        this.durationUnit = source.durationUnit();
        this.estimatedCostPerPerson = source.estimatedCostPerPerson();
        this.suggestedPlaceName = source.suggestedPlaceName();
        this.completionGuide = source.completionGuide();
        this.createdAt = now;
    }

    /**
     * 저장된 후보를 응답 모양으로 되돌린다. {@code index}는 화면 표시 순서라 호출부가 정한다.
     */
    public QuestRecommendationCandidate toResponse(int index) {
        return new QuestRecommendationCandidate(
            index, id, recommendationType, title, description, category,
            durationValue, durationUnit, estimatedCostPerPerson, suggestedPlaceName, completionGuide);
    }

    public void markClaimed(LocalDateTime now) {
        this.claimedAt = now;
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

    public String getTitle() {
        return title;
    }

    public String getDescription() {
        return description;
    }

    public String getSuggestedPlaceName() {
        return suggestedPlaceName;
    }

    public String getCompletionGuide() {
        return completionGuide;
    }

    public LocalDateTime getClaimedAt() {
        return claimedAt;
    }

    public boolean belongsTo(Long candidateUserId) {
        return userId.equals(candidateUserId);
    }

    public boolean isForPeriod(LocalDate period) {
        return periodStart.equals(period);
    }

    public boolean isClaimed() {
        return claimedAt != null;
    }
}
