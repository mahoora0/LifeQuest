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
import java.math.BigDecimal;
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
     * USERS.id 참조(팀원 1 소유). 크로스도메인 FK는 팀원 1 테이블에 제약을 발생시켜 퀘스트 도메인
     * 담당(팀원 2)이 단독으로 결정할 사안이 아니다 — BIGINT 컬럼으로만 둔다. 배정 단위 정합성은
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

    /**
     * 이 배정에만 적용되는 인증 좌표(V32). {@code null}이면 퀘스트 원본의 좌표를 쓴다.
     *
     * <p>장소 미지정 템플릿({@code Quest.isLocationTemplate()})을 배정할 때 사용자 주변으로
     * 만들어 붙인다. 원본이 아니라 배정에 두는 이유는 이 값이 사용자마다 다르기 때문이다 —
     * 원본 행을 고쳐 쓰면 같은 템플릿을 배정받은 다른 사용자의 좌표를 덮어쓴다.
     *
     * <p><b>완료 판정과 지도 표시가 같은 좌표를 봐야 한다.</b> 한쪽만 override를 반영하면
     * 사용자가 화면에서 본 지점과 인증되는 지점이 어긋나고, 그 어긋남은 실제로 거기까지 가 본
     * 사용자에게만 드러난다.
     *
     * <p>반경은 override 대상이 아니다 — 인증 반경은 장소의 성격이 정하는 값이고
     * (docs/05-business-rules.md §3-1) 템플릿 행이 이미 자기 반경을 갖고 있다.
     */
    @Column(name = "override_latitude", precision = 10, scale = 7)
    private BigDecimal overrideLatitude;

    @Column(name = "override_longitude", precision = 10, scale = 7)
    private BigDecimal overrideLongitude;

    /** 표시용 장소명. 실제 장소 API로 좌표를 채우게 되면 조회된 상호명이 여기 들어간다. */
    @Column(name = "override_place_name", length = 100)
    private String overridePlaceName;

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

    public BigDecimal getOverrideLatitude() {
        return overrideLatitude;
    }

    public BigDecimal getOverrideLongitude() {
        return overrideLongitude;
    }

    public String getOverridePlaceName() {
        return overridePlaceName;
    }

    /**
     * 이 배정에만 적용될 인증 좌표를 붙인다. 장소 미지정 템플릿을 배정할 때
     * {@code QuestAssignmentCreator}가 저장 직전에 부른다.
     *
     * <p>둘 중 하나만 있는 상태를 만들지 않는다. 위도만 덮이면 경도는 자리표가 남아 판정 지점이
     * 국토 한가운데로 가는데, 그 좌표도 유효한 좌표라 예외 없이 조용히 완료 불가가 된다.
     *
     * @param placeName 표시용 장소명. {@code null}이면 퀘스트 원본의 이름을 그대로 쓴다
     */
    public void applyLocationOverride(BigDecimal latitude, BigDecimal longitude, String placeName) {
        if (latitude == null || longitude == null) {
            throw new IllegalArgumentException(
                "override 좌표는 위도·경도가 함께 있어야 한다: lat=" + latitude + ", lng=" + longitude);
        }
        this.overrideLatitude = latitude;
        this.overrideLongitude = longitude;
        this.overridePlaceName = placeName;
    }

    /**
     * 이 배정의 실제 인증 지점. override가 있으면 그것, 없으면 퀘스트 원본의 좌표다.
     *
     * <p><b>완료 판정과 지도 표시가 모두 이 메서드를 지나야 한다.</b> 각자 삼항 연산으로 고르면
     * 한쪽이 override를 빠뜨려도 컴파일과 테스트가 통과하고, 어긋남은 그 지점까지 실제로 가 본
     * 사용자에게만 드러난다. 고르는 자리를 하나로 두면 그 경로가 생기지 않는다.
     *
     * @param quest 이 배정이 가리키는 퀘스트 원본
     * @throws IllegalArgumentException 다른 퀘스트를 넘긴 경우
     */
    public BigDecimal resolvedLatitude(Quest quest) {
        requireSameQuest(quest);
        return overrideLatitude != null ? overrideLatitude : quest.getLatitude();
    }

    /** 이 배정의 실제 인증 지점 경도. {@link #resolvedLatitude} 참조. */
    public BigDecimal resolvedLongitude(Quest quest) {
        requireSameQuest(quest);
        return overrideLongitude != null ? overrideLongitude : quest.getLongitude();
    }

    /** 화면에 보일 장소명. {@link #resolvedLatitude} 참조. */
    public String resolvedPlaceName(Quest quest) {
        requireSameQuest(quest);
        return overridePlaceName != null ? overridePlaceName : quest.getPlaceName();
    }

    /**
     * 넘어온 원본이 이 배정이 가리키는 퀘스트가 맞는지 본다. 배정과 퀘스트는 연관관계가 아니라
     * {@code questId} 값으로만 이어져 있어(크로스도메인 FK를 두지 않는다) 호출자가 목록을
     * 잘못 짝지어도 컴파일이 막지 못한다. 그러면 남의 좌표로 인증을 판정하게 된다.
     */
    private void requireSameQuest(Quest quest) {
        if (quest == null || !quest.getId().equals(questId)) {
            throw new IllegalArgumentException(
                "이 배정의 퀘스트가 아니다: 배정=" + questId
                    + ", 넘어온 퀘스트=" + (quest == null ? null : quest.getId()));
        }
    }

    public void markCompleted() {
        this.status = DailyQuestStatus.COMPLETED;
    }

    public void markExpired() {
        this.status = DailyQuestStatus.EXPIRED;
    }
}
