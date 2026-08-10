package com.lifequest.quest.service;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.domain.QuestFeature;
import com.lifequest.quest.domain.UserDailyQuest;
import com.lifequest.quest.dto.DailyQuestResponse;
import com.lifequest.quest.dto.QuestSummaryResponse;
import com.lifequest.quest.dto.TodayQuestsResponse;
import com.lifequest.quest.repository.QuestRepository;
import com.lifequest.quest.repository.UserDailyQuestRepository;
import com.lifequest.user.UserRepository;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 오늘의 퀘스트 조회. 배정이 없으면 그 자리에서 만든다(지연 생성, docs/05-business-rules.md §1).
 *
 * <h2>왜 READ_COMMITTED인가</h2>
 * MySQL 기본값 REPEATABLE READ 아래서는 트랜잭션의 <b>첫 조회가 read view를 굳혀</b>, 그 뒤 다른
 * 트랜잭션이 커밋한 행이 보이지 않는다. 이 메서드는 조회 → 생성 → <b>재조회</b> 순서라 정확히 그
 * 함정에 걸린다 — 경합에서 진 요청이 이긴 쪽의 배정을 못 보고 빈 목록을 응답하고, 앱을 두 번
 * 빠르게 연 사용자가 빈 화면을 본다.
 *
 * <p>락이 아니라 유니크 제약을 쓰는데도 완료 경로와 같은 함정에 걸린다. 무력화되는 대상이
 * 락이 아니라 재조회일 뿐이다.
 *
 * <p><b>이 결함은 "트랙당 3개" 테스트로는 안 잡힌다.</b> 배정이 6개로 늘지는 않기 때문이다.
 * 깨지는 것은 진 쪽의 <b>응답</b>이고 그것만 따로 재야 드러난다. H2로도 안 잡히므로
 * MySQL 실측이 필요하다.
 *
 * <p><b>지연 생성을 하는 진입점마다 어노테이션을 붙인다.</b> {@link #getNearbyQuests}가
 * {@link #getTodayQuests}를 자기호출로 부르므로 그 호출은 프록시를 거치지 않는다 — 바깥 진입점에
 * 같은 설정이 걸려 있어야 격리 수준이 실제로 적용된다.
 */
@Service
public class QuestAssignmentService {

    private final UserDailyQuestRepository userDailyQuestRepository;
    private final QuestRepository questRepository;
    private final UserRepository userRepository;
    private final QuestUnlockPolicy questUnlockPolicy;
    private final QuestAssignmentCreator questAssignmentCreator;
    private final QuestPeriod questPeriod;
    private final Clock clock;

    public QuestAssignmentService(UserDailyQuestRepository userDailyQuestRepository,
                                  QuestRepository questRepository,
                                  UserRepository userRepository,
                                  QuestUnlockPolicy questUnlockPolicy,
                                  QuestAssignmentCreator questAssignmentCreator,
                                  QuestPeriod questPeriod,
                                  Clock clock) {
        this.userDailyQuestRepository = userDailyQuestRepository;
        this.questRepository = questRepository;
        this.userRepository = userRepository;
        this.questUnlockPolicy = questUnlockPolicy;
        this.questAssignmentCreator = questAssignmentCreator;
        this.questPeriod = questPeriod;
        this.clock = clock;
    }

    /**
     * 지금 유효한 배정을 돌려준다. 잠금이 풀린 트랙 중 배정이 없는 것은 그 자리에서 만든다.
     *
     * <p>현재 시각을 <b>한 번만</b> 얻어 두 조회에 같은 값을 쓴다. 재조회에서 다시 읽으면
     * 그 사이에 만료된 배정이 목록에서 빠져 앞뒤 결과의 기준이 달라진다.
     *
     * <p>잠긴 트랙은 배정하지 않고 넘어간다 — 예외가 아니다. 조회는 잠긴 기능도 포함해
     * 화면을 그려야 하고, 승급하면 다음 조회의 지연 생성이 그 자리를 채운다.
     *
     * @return 유효한 배정. 트랙별로 최대 3개씩이며 잠긴 트랙은 비어 있다
     */
    @Transactional(readOnly = true, isolation = Isolation.READ_COMMITTED)
    public TodayQuestsResponse getTodayQuests(Long userId) {
        return getTodayQuests(userId, null, null);
    }

    /**
     * 사용자 주변을 반영해 조회한다. 위치는 <b>이번 호출이 배정을 만들 때만</b> 쓰인다 —
     * 이미 배정이 있으면 그대로 돌려주므로, 주기 도중에 다른 도시로 이동해도 그 주기의 배정은
     * 바뀌지 않는다. 배정이 도중에 갈리면 어제 보던 퀘스트가 사라지고 완료 이력의 기준도 흔들린다.
     *
     * @param latitude  사용자 현재 위도. {@code null}이면 위치를 모르는 것으로 본다
     * @param longitude 사용자 현재 경도
     */
    @Transactional(readOnly = true, isolation = Isolation.READ_COMMITTED)
    public TodayQuestsResponse getTodayQuests(Long userId, Double latitude, Double longitude) {
        LocalDateTime now = LocalDateTime.now(clock);
        List<UserDailyQuest> assigned =
            userDailyQuestRepository.findByUserIdAndExpiresAtAfter(userId, now);

        int level = userRepository.findById(userId)
            .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND))
            .getLevel();

        // 개인 AI 퀘스트는 "이 트랙의 자동 배정이 이미 있다"의 근거가 되지 못한다.
        //
        // AI 주간 퀘스트도 cadence가 WEEKLY라, 빼지 않으면 사용자가 자동 배정보다 AI 퀘스트를
        // 먼저 받았을 때 그 주 주간이 AI 1개로 끝난다 — 자동 2개가 영영 생기지 않는다.
        // 순서가 반대면(자동 먼저 → AI 나중) 정상 동작하므로 테스트에서 지나치기 쉽다.
        //
        // 판정 기준을 createdBy가 아니라 ownerUserId로 두는 이유는 Quest.ownerUserId 참조.
        //
        // 이 필터는 createForTrack을 부를지 정하는 빠른 판정일 뿐이고, 동시 요청에서 둘 다
        // "없음"을 봐도 중복 생성은 아래 마커 유니크 제약이 막는다 — 판정 주체는 여전히 DB다.
        Set<QuestCadence> assignedCadences = new HashSet<>();
        for (Quest quest : questsOf(assigned).values()) {
            if (quest.isPrivate()) {
                continue;
            }
            assignedCadences.add(quest.getCadence());
        }

        for (QuestCadence cadence : QuestCadence.values()) {
            if (!questUnlockPolicy.isUnlocked(level, feature(cadence))) {
                continue;
            }
            if (assignedCadences.contains(cadence)) {
                continue;
            }
            try {
                questAssignmentCreator.createForTrack(userId, cadence, latitude, longitude);
            } catch (DataIntegrityViolationException e) {
                // 다른 요청이 같은 주기의 마커를 먼저 넣었다 — 정상 흐름이다. 그쪽 트랜잭션이
                // 배정까지 만들었으므로 아래 재조회가 그것을 가져온다.
                //
                // 잡는 자리가 여기인 이유는 생성 트랜잭션이 REQUIRES_NEW이기 때문이다.
                // 안에서 잡으면 그 트랜잭션이 커밋을 시도하는데, flush가 실패한 세션은
                // 커밋될 수 없어 500이 된다. 밖에서 잡아야 롤백으로 끝난 뒤 이어갈 수 있다.
            }
        }

        List<UserDailyQuest> refreshed =
            userDailyQuestRepository.findByUserIdAndExpiresAtAfter(userId, now);

        return new TodayQuestsResponse(questPeriod.logicalDate(), toResponses(refreshed));
    }

    /**
     * 퀘스트 원본 상세. 배정 여부와 무관하다 — 완료 기록이나 도감에서 들어올 수 있고,
     * 그때 배정이 남아 있다는 보장이 없다.
     *
     * <p>비활성 퀘스트도 돌려준다. 배정 풀에서 빠졌을 뿐 과거에 완료한 기록은 유효하며,
     * 여기서 404를 내면 완료 이력 화면이 깨진다.
     *
     * <p><b>개인 AI 퀘스트는 주인만 볼 수 있다.</b> 이 검사가 없으면 id를 훑어 남의 개인
     * 퀘스트를 읽을 수 있다 — 추천 요청에 담긴 지역·예산·동행 인원이 제목과 설명에 그대로
     * 반영되므로 노출 대상이 퀘스트 문구만이 아니다.
     *
     * <p>403이 아니라 <b>404</b>를 준다. 403은 "그 id에 무언가 있다"를 알려주므로 존재 여부
     * 자체가 새고, 이 API는 없는 id에도 404를 주므로 두 경우를 구분할 수 없어야 한다.
     */
    @Transactional(readOnly = true)
    public QuestSummaryResponse getQuest(Long userId, Long questId) {
        Quest quest = questRepository.findById(questId)
            .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
        if (!quest.isVisibleTo(userId)) {
            throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        }
        return QuestSummaryResponse.from(quest);
    }

    /**
     * 오늘 배정된 LOCATION 퀘스트 중 주어진 반경 안에 있는 것(docs/04-api-spec.md §3).
     *
     * <p>{@link #getTodayQuests}를 거치므로 <b>지도 화면으로 먼저 들어와도 배정이 만들어진다.</b>
     * 목록을 먼저 열어야만 배정이 생기는 구조라면 진입 순서가 결과를 바꾼다.
     *
     * <p>거리 오름차순으로 정렬한다. 지도에서 가까운 것부터 보는 것이 자연스럽고, 정렬을
     * 앱에 맡기면 화면마다 기준이 갈린다.
     *
     * @param radiusKm 검색 반경(km). 퀘스트별 인증 반경({@code radius_m})과는 다른 값이다 —
     *                 이쪽은 "지도에서 얼마나 넓게 볼까"이고, 인증 판정은 완료 API가 한다
     */
    @Transactional(readOnly = true, isolation = Isolation.READ_COMMITTED)
    public List<DailyQuestResponse> getNearbyQuests(Long userId, Double lat, Double lng, Double radiusKm) {
        if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "위경도가 유효 범위를 벗어났습니다.");
        }
        if (radiusKm == null || radiusKm <= 0) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "검색 반경은 0보다 커야 합니다.");
        }

        double radiusM = radiusKm * 1000;
        List<DailyQuestResponse> nearby = new ArrayList<>();

        // 지도로 먼저 들어온 사용자의 배정도 그의 주변으로 만들어져야 한다. 여기서 좌표를 넘기지
        // 않으면 진입 순서가 결과를 바꾼다 — 목록을 먼저 연 사용자만 주변 퀘스트를 받는다
        for (DailyQuestResponse assignment : getTodayQuests(userId, lat, lng).quests()) {
            QuestSummaryResponse quest = assignment.quest();
            if (quest.latitude() == null || quest.longitude() == null) {
                continue;
            }

            double distance = GeoDistance.meters(
                lat, lng, quest.latitude().doubleValue(), quest.longitude().doubleValue());
            if (distance > radiusM) {
                continue;
            }

            nearby.add(new DailyQuestResponse(
                assignment.dailyQuestId(),
                assignment.questId(),
                assignment.status(),
                quest,
                BigDecimal.valueOf(distance).setScale(1, RoundingMode.HALF_UP)));
        }

        nearby.sort(Comparator.comparing(DailyQuestResponse::distanceM));
        return nearby;
    }

    private List<DailyQuestResponse> toResponses(List<UserDailyQuest> assigned) {
        Map<Long, Quest> quests = questsOf(assigned);
        List<DailyQuestResponse> responses = new ArrayList<>();
        for (UserDailyQuest assignment : assigned) {
            Quest quest = quests.get(assignment.getQuestId());
            // 배정이 가리키는 퀘스트가 사라지는 경로는 없다(시드는 삭제 대신 비활성). 그래도
            // null이면 그 항목만 빼고 나머지를 보낸다 — 목록 전체가 500이 되는 편이 더 나쁘다
            if (quest != null) {
                responses.add(DailyQuestResponse.of(assignment, quest));
            }
        }
        return responses;
    }

    /**
     * 배정이 가리키는 퀘스트들을 id로 묶어 돌려준다.
     *
     * <p>{@code UserDailyQuest}에 트랙 컬럼이 없어 {@code questId}로 원본을 봐야 한다. 배정 건이
     * 트랙당 3개씩 최대 6개뿐이라 조회 한 번으로 충분하며, 이 때문에 비정규화 컬럼을 두지 않는다.
     */
    private Map<Long, Quest> questsOf(List<UserDailyQuest> assigned) {
        if (assigned.isEmpty()) {
            return Map.of();
        }
        List<Long> questIds = new ArrayList<>();
        for (UserDailyQuest assignment : assigned) {
            questIds.add(assignment.getQuestId());
        }

        Map<Long, Quest> byId = new HashMap<>();
        for (Quest quest : questRepository.findAllById(questIds)) {
            byId.put(quest.getId(), quest);
        }
        return byId;
    }

    /**
     * 트랙에 대응하는 잠금 기능. 협동은 {@link QuestCadence}에 없으므로 여기 나타나지 않는다 —
     * 두 enum의 값 집합이 어긋나는 것은 의도된 것이다.
     */
    private QuestFeature feature(QuestCadence cadence) {
        return cadence == QuestCadence.WEEKLY ? QuestFeature.WEEKLY : QuestFeature.DAILY;
    }
}