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

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
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
        List<Quest> pool = new ArrayList<>();
        List<Quest> previouslyAssigned = new ArrayList<>();
        for (Quest quest : questRepository.findByActiveTrueAndOwnerUserIdIsNull()) {
            if (quest.getCadence() != cadence) {
                continue;
            }
            if (previousQuestIds.contains(quest.getId())) {
                previouslyAssigned.add(quest);
            } else {
                pool.add(quest);
            }
        }

        for (Quest drawn : questSlotDrawer.questDrawer(slotsFor(cadence), pool, previouslyAssigned)) {
            userDailyQuestRepository.save(
                new UserDailyQuest(userId, drawn.getId(), periodStart, expiresAt));
        }
    }
}
