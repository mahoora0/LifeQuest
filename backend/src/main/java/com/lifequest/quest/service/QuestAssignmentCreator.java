package com.lifequest.quest.service;

import com.lifequest.quest.domain.CompletionType;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.domain.QuestAssignmentMarker;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.domain.UserDailyQuest;
import com.lifequest.quest.repository.QuestAssignmentMarkerRepository;
import com.lifequest.quest.repository.QuestRepository;
import com.lifequest.quest.repository.UserDailyQuestRepository;
import jakarta.validation.constraints.NotNull;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.validation.annotation.Validated;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Random;
import java.util.Set;

/**
 * 트랙 하나의 배정 생성 트랜잭션(docs/05-business-rules.md §1).
 *
 * <h2>왜 트랙마다 별도 트랜잭션인가</h2>
 * <b>마커 유니크 위반이 오류가 아니라 정상 흐름</b>이기 때문이다. 한 트랜잭션에서 두 트랙을
 * 처리하면 일간 마커 위반이 Hibernate 세션을 오염시키고 rollback-only가 박혀 주간 생성을
 * 이어갈 수 없다. 트랙 분리를 클래스 분리로까지 끌고 온 이유이며,
 * <b>같은 빈 안에서 부르면 프록시를 거치지 않아 {@code REQUIRES_NEW}가 통째로 무시된다</b> —
 * {@link QuestAssignmentService}가 이 클래스를 주입받아 부르는 형태여야 한다.
 *
 * <h2>마커를 가장 먼저 저장한다</h2>
 * 배정은 지연 생성이라 같은 사용자의 동시 요청이 모두 "배정 없음"을 보고 각각 생성을 시도할 수
 * 있다. {@code uk_user_daily_quests}는 이를 막지 못한다 — 두 요청이 서로 다른 퀘스트를 뽑으면
 * 겹치는 행이 없어 제약에 걸리지 않고 한 트랙에 6개가 배정된다. 판정 주체를 애플리케이션 조회가
 * 아니라 DB 제약으로 두면 인스턴스를 늘려도 무력화되지 않는다.
 *
 * <p><b>{@code saveAndFlush}여야 한다.</b> JPA는 INSERT를 flush 시점까지 미루므로 {@code save}만
 * 하면 위반이 트랜잭션 커밋에서 터진다. 그때는 이미 catch 블록 밖이라 "경합에서 졌으니 재조회"
 * 경로로 갈 수 없고 요청이 500으로 끝난다.
 *
 * <h2>격리수준을 여기 걸지 않는 이유</h2>
 * 이 트랜잭션은 자기가 쓴 것만 읽으므로 read view가 굳어도 영향이 없다. 격리수준이 실제로
 * 필요한 자리는 <b>생성 뒤 재조회를 하는</b> {@link QuestAssignmentService} 쪽이다.
 */
@Service
@Validated
public class QuestAssignmentCreator {

    /**
     * 일간 슬롯 구성 — A는 LOCATION, B는 SELF_REPORT, C는 타입 제한 없이 잔여에서 고른다.
     *
     * <p>추출기가 이 리스트의 원소를 변형하지 않는 계약이라 상수로 공유해도 안전하다 —
     * 완화는 슬롯마다 뜨는 복사본에만 적용된다({@link QuestSlotDrawer} 참조).
     */
    private static final List<Set<CompletionType>> DAILY_SLOTS = List.of(
        Set.of(CompletionType.LOCATION),
        Set.of(CompletionType.SELF_REPORT),
        Set.of(CompletionType.values()));

    /**
     * 주간 <b>자동</b> 슬롯 구성 — A·B만 뽑고 C는 비워 둔다.
     *
     * <p>세 번째 자리는 사용자가 AI 추천 중에서 직접 고른다({@code WeeklyAiQuestService}).
     * 자동으로 채워 버리면 사용자가 고를 자리가 없어지고, 그렇다고 네 번째로 얹으면
     * "트랙당 3개" 계약이 깨진다.
     *
     * <p>여기서 빼는 것은 <b>타입 제한 없는 슬롯 C</b>다. A(LOCATION)를 남기는 이유는 AI가 그
     * 자리를 대신할 수 없기 때문이다 — 추천은 좌표를 만들지 못하므로 항상 SELF_REPORT다.
     * C를 빼면 잃는 것은 "잔여에서 아무거나 하나"뿐이라 손실이 가장 작다.
     */
    private static final List<Set<CompletionType>> WEEKLY_AUTO_SLOTS = List.of(
        Set.of(CompletionType.LOCATION),
        Set.of(CompletionType.SELF_REPORT));

    private static List<Set<CompletionType>> slotsFor(QuestCadence cadence) {
        return cadence == QuestCadence.WEEKLY ? WEEKLY_AUTO_SLOTS : DAILY_SLOTS;
    }

    /**
     * 갈 수 있다고 보는 거리(m). 이 안의 LOCATION 퀘스트만 후보가 된다.
     *
     * <p><b>트랙마다 다르다.</b> 두 트랙이 요구하는 이동의 크기가 다르기 때문이다 — 일간은
     * 오늘 안에 다녀와야 하고 주간은 한 번 마음먹고 나가는 활동이다(docs/05-business-rules.md §1).
     * 하나로 두면 한쪽이 반드시 어긋난다. 50km로 통일하면 서울 사용자의 오늘 퀘스트가 송도가
     * 될 수 있고, 15km로 통일하면 주간의 나들이 성격이 사라진다.
     *
     * <p>일간에서 밀려난 사용자는 빈손이 되지 않는다 — 템플릿이 그 자리를 받아 사용자 주변
     * 몇백 미터 지점을 만든다. 좁힐수록 나빠지는 것이 아니라 <b>실재 장소에서 근처 걷기로
     * 바뀌는 것</b>이라, 일간은 좁게 잡는 편이 뜻에 맞는다.
     *
     * <p>주간의 50km는 광역시 하나와 인접 도시를 덮는다 — 수원·성남이 서울권에, 김해·양산이
     * 부산권에 들어온다.
     */
    static final double DAILY_NEARBY_RADIUS_M = 15_000;
    static final double WEEKLY_NEARBY_RADIUS_M = 50_000;

    static double nearbyRadiusM(QuestCadence cadence) {
        return cadence == QuestCadence.WEEKLY ? WEEKLY_NEARBY_RADIUS_M : DAILY_NEARBY_RADIUS_M;
    }

    /**
     * 템플릿 지점을 사용자에게서 얼마나 떨어뜨릴지 — 그 퀘스트 인증 반경에 대한 비율.
     *
     * <p>하한을 두는 이유는 사용자가 선 자리에서 이미 인증되는 퀘스트를 만들지 않기 위해서다.
     * 상한을 반경 아래로 두는 이유는 반대다 — 반경 밖으로 나가면 그 지점에 도착하고도 인증이
     * 안 되는 것이 아니라, 지점 주변의 인증 가능 범위가 사용자 쪽으로 치우쳐 "가다가 완료되는"
     * 구간이 생긴다.
     */
    private static final double TEMPLATE_OFFSET_MIN_RATIO = 0.2;
    private static final double TEMPLATE_OFFSET_MAX_RATIO = 0.8;

    private final QuestAssignmentMarkerRepository questAssignmentMarkerRepository;
    private final QuestRepository questRepository;
    private final UserDailyQuestRepository userDailyQuestRepository;
    private final QuestPeriod questPeriod;
    private final QuestSlotDrawer questSlotDrawer;
    private final Clock clock;

    public QuestAssignmentCreator(QuestAssignmentMarkerRepository questAssignmentMarkerRepository,
                                  QuestRepository questRepository,
                                  UserDailyQuestRepository userDailyQuestRepository,
                                  QuestPeriod questPeriod,
                                  QuestSlotDrawer questSlotDrawer,
                                  Clock clock) {
        this.questAssignmentMarkerRepository = questAssignmentMarkerRepository;
        this.questRepository = questRepository;
        this.userDailyQuestRepository = userDailyQuestRepository;
        this.questPeriod = questPeriod;
        this.questSlotDrawer = questSlotDrawer;
        this.clock = clock;
    }

    /**
     * 한 트랙의 이번 주기 배정을 만든다. 이미 만들어져 있으면 아무것도 하지 않는다.
     *
     * <p>주기는 인자로 받지 않고 {@link QuestPeriod}에서 <b>한 번</b> 얻는다. 호출자가 날짜를
     * 넘기는 형태였다면 그 자리에 {@code LocalDate.now()}가 들어가도 컴파일과 테스트가 통과하고,
     * 그 결함은 매일 00:00~04:00 사용자 전체에 걸리며 스스로 낫지 않는다. 같은 이유로
     * {@code periodStart}와 {@code expiresAt}도 같은 계산 결과에서 함께 꺼낸다 — 따로 부르면
     * 그 사이에 04:00을 넘길 때 시작일과 만료가 다른 주기를 가리킨다.
     *
     * @param userId  배정 대상
     * @param cadence 트랙. 슬롯 수·갱신 주기가 트랙마다 따로다
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void createForTrack(@NotNull Long userId, @NotNull QuestCadence cadence) {
        createForTrack(userId, cadence, null, null);
    }

    /**
     * 사용자 주변을 반영해 한 트랙의 배정을 만든다.
     *
     * <p>위치는 <b>LOCATION 후보를 좁히는 데만</b> 쓴다. 등급 확률·슬롯 구성·직전 주기 제외는
     * 그대로다 — 위치가 바꾸는 것은 "어느 장소가 후보인가"뿐이고 "무엇을 몇 개 뽑는가"가 아니다.
     *
     * @param latitude  사용자 현재 위도. {@code null}이면 위치를 모르는 것으로 보고
     *                  기존처럼 카탈로그 전체를 후보로 삼는다
     * @param longitude 사용자 현재 경도
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void createForTrack(@NotNull Long userId, @NotNull QuestCadence cadence,
                               Double latitude, Double longitude) {
        QuestPeriod.QuestLifePeriod period = questPeriod.create(cadence);
        LocalDate periodStart = period.getStartAt();
        LocalDateTime expiresAt = period.getExpiresAt();

        // 유니크 위반을 여기서 잡지 않는다. 잡고 return하면 Spring이 이 트랜잭션을 커밋하려
        // 드는데, flush가 실패한 Hibernate 세션은 커밋될 수 없어 요청이 500으로 끝난다.
        // 예외가 밖으로 나가야 이 트랜잭션이 롤백으로 정상 종료되고, 호출자가 그것을
        // "경합에서 짐"으로 읽어 재조회로 넘어갈 수 있다.
        //
        // ⚠ 이 경로는 동시 요청에서만 실행된다. 순차 호출은 두 번째에 배정이 이미 있어
        // 호출자가 여기까지 오지 않으므로, 단위 테스트로는 지나가지 않는 자리다.
        questAssignmentMarkerRepository.saveAndFlush(
            new QuestAssignmentMarker(userId, cadence, periodStart, LocalDateTime.now(clock)));

        Set<Long> previousQuestIds = new HashSet<>();
        for (UserDailyQuest previous : userDailyQuestRepository.findByUserIdAndAssignedDate(
            userId, questPeriod.previousPeriodStart(cadence))) {
            previousQuestIds.add(previous.getQuestId());
        }

        // 직전 주기 배정분을 빼는 것이 아니라 갈라 둔다. 추출기가 완화 ①에서 그쪽을 후보로
        // 되살리기 때문이다 — 여기서 버리면 슬롯을 채울 수 있는데도 비는 경우가 생긴다
        // 개인 AI 퀘스트는 풀 조회 단계에서 이미 빠진다(owner_user_id IS NULL). 지난 주기의 AI
        // 퀘스트 id가 previousQuestIds에 남아 있어도 대조할 대상이 없어 그냥 무시된다 — 정상이며,
        // §1-B의 "직전 주기 제외"는 공용 카탈로그에만 적용된다.
        List<Quest> thisTrack = new ArrayList<>();
        for (Quest quest : questRepository.findByActiveTrueAndOwnerUserIdIsNull()) {
            if (quest.getCadence() == cadence) {
                thisTrack.add(quest);
            }
        }

        // 위치로 좁히는 것이 직전 주기 제외보다 먼저다. 순서가 뒤집히면 "어제 배정된 부산 퀘스트"가
        // 서울 사용자의 완화 ① 후보로 남아, 슬롯을 채우지 못할 때 그 사용자가 갈 수 없는 장소가
        // 되살아난다 — 완화는 제약을 푸는 장치지 후보의 유효 범위를 넓히는 장치가 아니다
        List<Quest> reachable = withinReach(thisTrack, cadence, latitude, longitude);

        // 직전 주기 배정분을 빼는 것이 아니라 갈라 둔다. 추출기가 완화 ①에서 그쪽을 후보로
        // 되살리기 때문이다 — 여기서 버리면 슬롯을 채울 수 있는데도 비는 경우가 생긴다
        // 개인 AI 퀘스트는 풀 조회 단계에서 이미 빠진다(owner_user_id IS NULL). 지난 주기의 AI
        // 퀘스트 id가 previousQuestIds에 남아 있어도 대조할 대상이 없어 그냥 무시된다 — 정상이며,
        // §1-B의 "직전 주기 제외"는 공용 카탈로그에만 적용된다.
        List<Quest> pool = new ArrayList<>();
        List<Quest> previouslyAssigned = new ArrayList<>();
        for (Quest quest : reachable) {
            if (previousQuestIds.contains(quest.getId())) {
                previouslyAssigned.add(quest);
            } else {
                pool.add(quest);
            }
        }

        Random random = new Random();
        for (Quest drawn : questSlotDrawer.questDrawer(slotsFor(cadence), pool, previouslyAssigned)) {
            UserDailyQuest assignment =
                new UserDailyQuest(userId, drawn.getId(), periodStart, expiresAt);
            if (drawn.isLocationTemplate()) {
                GeoDistance.Point point = templatePoint(drawn, latitude, longitude, random);
                // 장소명은 넘기지 않는다 — 템플릿의 place_name("현재 위치 주변")이 이미 그 뜻이고,
                // 좌표에서 지어낸 이름은 실제 장소 API를 붙일 때 덮일 임시값이 된다
                assignment.applyLocationOverride(scaled(point.latitude()), scaled(point.longitude()), null);
            }
            userDailyQuestRepository.save(assignment);
        }
    }

    /**
     * LOCATION 후보를 사용자가 갈 수 있는 것으로 좁힌다. LOCATION이 아닌 퀘스트는 그대로 지난다 —
     * 이 필터가 다루는 것은 장소이며 직접 완료 퀘스트에는 장소가 없다.
     *
     * <h2>세 갈래</h2>
     * <ol>
     *   <li><b>위치를 모른다</b> — 템플릿만 빼고 카탈로그 전체를 후보로 둔다. 템플릿은 좌표를
     *       만들 기준이 없으면 자리표가 그대로 인증 지점이 되므로 여기 들어와서는 안 된다.
     *   <li><b>주변에 시드된 장소가 있다</b> — 그것만 남긴다. 템플릿은 빼는데, 실재하는 장소가
     *       있는데도 좌표만 찍힌 지점을 섞으면 후자가 항상 더 심심하다.
     *   <li><b>주변에 아무것도 없다</b> — 템플릿만 남긴다. 여기서 빈 목록을 돌려주면 슬롯 A가
     *       타입 완화로 넘어가 그 사용자는 위치 퀘스트를 영영 받지 못한다.
     * </ol>
     *
     * <p>나중에 실제 장소 API(카카오·구글 Places)로 옮길 때 바뀌는 자리는 ③뿐이다 — 템플릿
     * 대신 조회한 장소로 채우게 된다. ①·②는 그대로 남으므로 이 메서드 밖은 건드릴 일이 없다.
     */
    private List<Quest> withinReach(List<Quest> quests, QuestCadence cadence,
                                    Double latitude, Double longitude) {
        double radiusM = nearbyRadiusM(cadence);
        List<Quest> result = new ArrayList<>();
        List<Quest> templates = new ArrayList<>();
        boolean anyNearby = false;

        for (Quest quest : quests) {
            if (!quest.isLocationBased()) {
                result.add(quest);
                continue;
            }
            if (quest.isLocationTemplate()) {
                templates.add(quest);
                continue;
            }
            if (latitude == null || longitude == null) {
                result.add(quest);
                continue;
            }
            double distance = GeoDistance.meters(
                latitude, longitude,
                quest.getLatitude().doubleValue(), quest.getLongitude().doubleValue());
            if (distance <= radiusM) {
                result.add(quest);
                anyNearby = true;
            }
        }

        if (!anyNearby && latitude != null && longitude != null) {
            result.addAll(templates);
        }
        return result;
    }

    /**
     * 템플릿 퀘스트의 인증 지점을 사용자 주변에 만든다.
     *
     * <p>거리를 반경의 일부로 잡는 이유는 반경이 그 퀘스트가 뜻하는 활동 크기를 이미 담고 있기
     * 때문이다. 고정 미터로 두면 반경을 조정할 때마다 이 상수도 함께 맞춰야 하고, 맞추지 않아도
     * 아무 징후가 없다.
     *
     * <p>방위각은 균등하게 뽑는다. 거리와 방위각을 각각 균등하게 뽑으면 지점이 사용자 쪽으로
     * 몰리지만(면적이 반지름에 비례하므로) 여기서는 그게 문제가 아니다 — 목적이 원판 위 균등
     * 분포가 아니라 "매번 다른 방향으로 조금 걷게 하는 것"이다.
     *
     * @throws IllegalStateException 사용자 좌표 없이 템플릿이 뽑힌 경우.
     *     {@link #withinReach}가 그 경로를 막고 있으므로 여기 닿았다면 그쪽이 깨진 것이다.
     *     조용히 자리표 좌표를 쓰면 국토 한가운데가 인증 지점이 되어 완료 불가가 된다
     */
    private GeoDistance.Point templatePoint(Quest template, Double latitude, Double longitude,
                                            Random random) {
        if (latitude == null || longitude == null) {
            throw new IllegalStateException(
                "사용자 좌표 없이 템플릿 퀘스트가 배정됐다: questId=" + template.getId());
        }

        double ratio = TEMPLATE_OFFSET_MIN_RATIO
            + random.nextDouble() * (TEMPLATE_OFFSET_MAX_RATIO - TEMPLATE_OFFSET_MIN_RATIO);

        return GeoDistance.offset(
            latitude, longitude, template.getRadiusM() * ratio, random.nextDouble() * 360);
    }

    /**
     * {@code DECIMAL(10,7)} 컬럼에 맞춰 자른다. 자리수를 맞추지 않으면 JDBC 드라이버가 반올림해
     * 넣으므로 저장은 되지만, 저장 전후의 값이 달라져 방금 만든 지점과 조회한 지점이 어긋난다.
     * 소수점 일곱째 자리는 약 1cm라 인증 판정에는 영향이 없다.
     */
    private static BigDecimal scaled(double degrees) {
        return BigDecimal.valueOf(degrees).setScale(7, RoundingMode.HALF_UP);
    }
}
