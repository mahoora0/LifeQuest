package com.lifequest.quest.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 퀘스트 원본 정의(QUESTS). 배정·완료의 기준 데이터이며 소유자는 팀원 2다.
 *
 * <p>LOCATION 타입만 {@code placeName}·{@code latitude}·{@code longitude}·{@code radiusM}를 사용한다.
 * 배정/완료/GPS 판정 로직은 서비스 계층(팀원 2 직접 구현)에서 다루며, 이 엔티티는 데이터 정의에 한정한다.
 */
@Entity
@Table(name = "quests")
public class Quest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "title", nullable = false, length = 100)
    private String title;

    @Column(name = "description", length = 500)
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(name = "grade", nullable = false, length = 20)
    private QuestGrade grade;

    @Enumerated(EnumType.STRING)
    @Column(name = "completion_type", nullable = false, length = 20)
    private CompletionType completionType;

    @Column(name = "exp_reward", nullable = false)
    private int expReward;

    @Column(name = "place_name", length = 100)
    private String placeName;

    @Column(name = "latitude", precision = 10, scale = 7)
    private BigDecimal latitude;

    @Column(name = "longitude", precision = 10, scale = 7)
    private BigDecimal longitude;

    @Column(name = "radius_m")
    private Integer radiusM;

    /** LIFEDEX_ITEMS.id 참조(팀원 3). 테이블 미존재로 FK 제약은 후속 마이그레이션에서 추가한다. */
    @Column(name = "lifedex_item_id")
    private Long lifedexItemId;

    @Enumerated(EnumType.STRING)
    @Column(name = "created_by", nullable = false, length = 20)
    private QuestCreator createdBy;

    @Column(name = "is_active", nullable = false)
    private boolean active = true;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    protected Quest() {
    }

    public Quest(String title, String description, QuestGrade grade, CompletionType completionType,
                 int expReward, String placeName, BigDecimal latitude, BigDecimal longitude,
                 Integer radiusM, Long lifedexItemId, QuestCreator createdBy, boolean active) {
        this.title = title;
        this.description = description;
        this.grade = grade;
        this.completionType = completionType;
        this.expReward = expReward;
        this.placeName = placeName;
        this.latitude = latitude;
        this.longitude = longitude;
        this.radiusM = radiusM;
        this.lifedexItemId = lifedexItemId;
        this.createdBy = createdBy;
        this.active = active;
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
    }

    public Long getId() {
        return id;
    }

    public String getTitle() {
        return title;
    }

    public String getDescription() {
        return description;
    }

    public QuestGrade getGrade() {
        return grade;
    }

    public CompletionType getCompletionType() {
        return completionType;
    }

    public int getExpReward() {
        return expReward;
    }

    public String getPlaceName() {
        return placeName;
    }

    public BigDecimal getLatitude() {
        return latitude;
    }

    public BigDecimal getLongitude() {
        return longitude;
    }

    public Integer getRadiusM() {
        return radiusM;
    }

    public Long getLifedexItemId() {
        return lifedexItemId;
    }

    public QuestCreator getCreatedBy() {
        return createdBy;
    }

    public boolean isActive() {
        return active;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public boolean isLocationBased() {
        return completionType == CompletionType.LOCATION;
    }

    /** 관리자 소프트 삭제: 실제 행 삭제 대신 배정 풀에서 제외한다(docs/05-business-rules.md §11). */
    public void deactivate() {
        this.active = false;
    }
}
