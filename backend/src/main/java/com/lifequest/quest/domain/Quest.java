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
 * <p>LOCATION 타입만 {@code placeName}·{@code latitude}·{@code longitude}·{@code radiusM}을 사용한다.
 * 배정/완료/GPS 판정 로직은 서비스 계층(팀원 2 직접 구현)에서 다루며, 이 엔티티는 데이터 정의에 한정한다.
 *
 * <p><b>불변식:</b> LOCATION 퀘스트는 좌표와 양수 반경을 반드시 갖는다. 생성자가 이를 강제하고
 * 마이그레이션의 {@code ck_quests_location_verifiable} CHECK 제약이 애플리케이션을 우회한 삽입까지 막는다.
 * 근거는 {@link #isLocationBased()} 참조.
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

    /** 반복 주기(일간·주간·월간). 목록 화면의 조회 필터 기준이며 완료 방식과는 별개의 축이다. */
    @Enumerated(EnumType.STRING)
    @Column(name = "cadence", nullable = false, length = 20)
    private QuestCadence cadence;

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

    public Quest(String title, String description, QuestGrade grade, QuestCadence cadence,
                 CompletionType completionType, int expReward, String placeName,
                 BigDecimal latitude, BigDecimal longitude, Integer radiusM, Long lifedexItemId,
                 QuestCreator createdBy, boolean active) {
        requireVerifiableIfLocation(completionType, latitude, longitude, radiusM);
        this.title = title;
        this.description = description;
        this.grade = grade;
        this.cadence = cadence;
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

    /**
     * LOCATION 퀘스트에 좌표·반경이 비어 있으면 배정된 사용자가 완료도 해제도 못 하는 상태에 빠진다
     * (GPS 판정이 {@code radiusM} 언박싱에서 NPE를 던지거나 null 좌표로 거리 계산을 시도한다).
     * 그런 행이 {@code findByActiveTrue()} 배정 풀에 들어가는 것을 생성 시점에 차단한다.
     * 반경 0은 어떤 위치도 통과하지 못하므로 같은 막다른 길이라 함께 거부한다.
     */
    private static void requireVerifiableIfLocation(CompletionType completionType,
                                                    BigDecimal latitude, BigDecimal longitude,
                                                    Integer radiusM) {
        if (completionType != CompletionType.LOCATION) {
            return;
        }
        if (latitude == null || longitude == null) {
            throw new IllegalArgumentException("LOCATION 퀘스트는 latitude·longitude가 필요하다");
        }
        if (radiusM == null || radiusM <= 0) {
            throw new IllegalArgumentException("LOCATION 퀘스트는 양수 radius_m이 필요하다: " + radiusM);
        }
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

    public QuestCadence getCadence() {
        return cadence;
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

    public void update(
            String title,
            String description,
            QuestGrade grade,
            QuestCadence cadence,
            CompletionType completionType,
            int expReward,
            String placeName,
            BigDecimal latitude,
            BigDecimal longitude,
            Integer radiusM,
            Long lifedexItemId,
            boolean active) {
        requireVerifiableIfLocation(completionType, latitude, longitude, radiusM);
        this.title = title;
        this.description = description;
        this.grade = grade;
        this.cadence = cadence;
        this.completionType = completionType;
        this.expReward = expReward;
        this.placeName = placeName;
        this.latitude = latitude;
        this.longitude = longitude;
        this.radiusM = radiusM;
        this.lifedexItemId = lifedexItemId;
        this.active = active;
    }
}
