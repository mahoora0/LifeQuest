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

    /**
     * AI 주간 퀘스트의 고정 등급. §2의 RARE 대역(30~50 EXP)에 맞췄고, 기존 주간 SELF_REPORT
     * 시드가 쓰는 값(35·40)과 같은 자리다. 사용자가 예산·기간을 부풀려 상위 등급을 노리는 경로가
     * 생기지 않도록 후보 내용과 무관하게 고정한다.
     */
    public static final QuestGrade AI_QUEST_GRADE = QuestGrade.RARE;

    /** AI 주간 퀘스트의 고정 EXP. {@link #AI_QUEST_GRADE} 참조. */
    public static final int AI_QUEST_EXP_REWARD = 40;

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

    /** 반복 주기(일간·주간). 배정 트랙을 가르는 기준이며 완료 방식과는 별개의 축이다. */
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

    /**
     * 장소를 특정하지 않는 퀘스트인가(V32·V33). {@code true}면 위 좌표는 배정 시점에 사용자
     * 주변으로 만들어진 좌표로 덮인다({@code UserDailyQuest}의 override 컬럼).
     *
     * <p><b>좌표 {@code null}로는 이 구분을 할 수 없다.</b> 좌표 없는 LOCATION은
     * {@link #requireVerifiableIfLocation}과 {@code ck_quests_location_verifiable}이 거부하며
     * 그 제약은 유지되어야 한다. 그래서 템플릿 행도 좌표를 갖고, 별도 플래그로 "이 좌표는 기준이
     * 아니라 자리표"임을 나타낸다.
     *
     * <p>배정 후보가 되는 경로는 <b>사용자 좌표가 있을 때 하나뿐</b>이다
     * ({@code QuestAssignmentCreator}). 좌표 없이 배정되면 자리표가 그대로 인증 지점이 되므로
     * 그 경로를 열어서는 안 된다.
     */
    @Column(name = "is_location_template", nullable = false)
    private boolean locationTemplate = false;

    /** LIFEDEX_ITEMS.id 참조. LOCATION 퀘스트의 수집 항목은 V25에서 연결한다. */
    @Column(name = "lifedex_item_id")
    private Long lifedexItemId;

    @Enumerated(EnumType.STRING)
    @Column(name = "created_by", nullable = false, length = 20)
    private QuestCreator createdBy;

    /**
     * 개인 전용 퀘스트의 주인. {@code null}이면 공용 카탈로그다(docs/05-business-rules.md §1).
     *
     * <p><b>배정 풀·상세 권한·어드민 관리는 전부 이 컬럼으로 공용/개인을 가른다.</b>
     * {@code createdBy}가 아니라 이쪽을 보는 이유는 두 축이 다른 것을 말하기 때문이다 —
     * createdBy는 "누가 만들었나", ownerUserId는 "누구 것인가"다. AI가 나중에 공용 카탈로그를
     * 생성하게 되면 {@code createdBy == AI}로 개인 여부를 판정하던 자리가 전부 틀어진다.
     */
    @Column(name = "owner_user_id")
    private Long ownerUserId;

    /**
     * 완료 기준 설명. {@code SELF_REPORT}는 시스템이 판정하지 않으므로 사용자에게는 이 문장이
     * 유일한 완료 기준이다. 공용 시드 퀘스트는 아직 {@code null}이다.
     */
    @Column(name = "completion_guide", length = 300)
    private String completionGuide;

    @Column(name = "is_active", nullable = false)
    private boolean active = true;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    protected Quest() {
    }

    /**
     * 공용 카탈로그 퀘스트를 만든다. {@code ownerUserId}는 항상 {@code null}이므로
     * <b>이 생성자로는 개인 AI 퀘스트를 만들 수 없다</b> — 그쪽은
     * {@link #createPrivateAiWeekly}만 통한다. 소유·등급·EXP를 서버가 고정하는 자리를
     * 하나로 좁혀 두면 호출부가 늘어도 불변식이 새지 않는다.
     */
    public Quest(String title, String description, QuestGrade grade, QuestCadence cadence,
                 CompletionType completionType, int expReward, String placeName,
                 BigDecimal latitude, BigDecimal longitude, Integer radiusM, Long lifedexItemId,
                 QuestCreator createdBy, boolean active) {
        requireVerifiableIfLocation(completionType, latitude, longitude, radiusM);
        requireAiOwnership(createdBy, null);
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
     * 사용자가 고른 AI 추천 후보를 개인 주간 퀘스트로 만든다.
     *
     * <p><b>등급·EXP·완료 방식·주기를 인자로 받지 않는다.</b> 전부 서버가 고정한다 — LLM 응답이나
     * 앱 요청에서 받으면 보상을 부풀리는 경로가 열린다. 추천 후보가 나르는 것은 텍스트(제목·설명·
     * 장소·완료 가이드)뿐이고, 그 값들은 {@code QuestRecommendationValidator}가 이미 길이·예산·
     * 기간을 검증한 것이다.
     *
     * <p>완료 방식이 {@code SELF_REPORT}인 것은 선택이 아니라 제약이다. 추천 시스템 지시가
     * 좌표와 인증 반경을 만들지 못하게 막고 있고({@code QuestRecommendationPromptFactory}),
     * 좌표 없는 LOCATION은 {@link #requireVerifiableIfLocation}과 {@code ck_quests_location_verifiable}이
     * 거부한다. {@code suggestedPlaceName}은 표시용 이름일 뿐 좌표가 아니다.
     *
     * @param ownerUserId 이 퀘스트를 고른 사용자. 배정 풀과 상세 권한이 이 값으로 갈린다
     */
    public static Quest createPrivateAiWeekly(Long ownerUserId, String title, String description,
                                              String placeName, String completionGuide) {
        Quest quest = new Quest(
            title, description, AI_QUEST_GRADE, QuestCadence.WEEKLY,
            CompletionType.SELF_REPORT, AI_QUEST_EXP_REWARD, placeName,
            null, null, null, null, QuestCreator.SYSTEM, true);
        // 공용 생성자는 ownerUserId를 받지 않는다(그쪽으로 개인 퀘스트가 새지 않게 하려는 것이다).
        // 여기서 소유자와 생성 주체를 함께 덮어쓴 뒤 불변식을 다시 확인한다.
        quest.ownerUserId = ownerUserId;
        quest.createdBy = QuestCreator.AI;
        quest.completionGuide = completionGuide;
        requireAiOwnership(quest.createdBy, quest.ownerUserId);
        return quest;
    }

    /**
     * {@code created_by}와 {@code owner_user_id}는 함께 움직인다. AI인데 주인이 없으면 아무에게도
     * 배정되지 않으면서 배정 풀에서도 빠진 고아 행이 되고, 공용인데 주인이 있으면 그 사용자에게만
     * 보이는 카탈로그 퀘스트가 된다. 둘 다 예외도 로그도 없이 조용히 틀리는 종류라
     * {@code ck_quests_ai_owner} CHECK와 함께 양쪽에서 막는다.
     */
    private static void requireAiOwnership(QuestCreator createdBy, Long ownerUserId) {
        if (createdBy == QuestCreator.AI && ownerUserId == null) {
            throw new IllegalArgumentException("AI 퀘스트는 owner_user_id가 필요하다");
        }
        if (createdBy != QuestCreator.AI && ownerUserId != null) {
            throw new IllegalArgumentException(
                "공용 퀘스트는 owner_user_id를 가질 수 없다: " + ownerUserId);
        }
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

    /** {@code null}이면 공용 카탈로그, 값이 있으면 그 사용자 전용 퀘스트다. */
    public Long getOwnerUserId() {
        return ownerUserId;
    }

    public String getCompletionGuide() {
        return completionGuide;
    }

    /** 특정 사용자 전용 퀘스트인가. 배정 풀·상세 권한·어드민 목록의 판정 기준이다. */
    public boolean isPrivate() {
        return ownerUserId != null;
    }

    /** 이 사용자가 볼 수 있는가. 공용은 누구나, 개인은 주인만 볼 수 있다. */
    public boolean isVisibleTo(Long userId) {
        return ownerUserId == null || ownerUserId.equals(userId);
    }

    public boolean isLocationBased() {
        return completionType == CompletionType.LOCATION;
    }

    /**
     * 좌표를 배정 시점에 정하는 퀘스트인가. 시드된 도시가 주변에 없는 사용자에게만 배정된다.
     * 근거는 {@link #locationTemplate} 참조.
     */
    public boolean isLocationTemplate() {
        return locationTemplate;
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
