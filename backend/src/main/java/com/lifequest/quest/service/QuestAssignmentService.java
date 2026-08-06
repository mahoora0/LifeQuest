package com.lifequest.quest.service;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.domain.QuestFeature;
import com.lifequest.quest.domain.UserDailyQuest;
import com.lifequest.quest.repository.QuestRepository;
import com.lifequest.quest.repository.UserDailyQuestRepository;
import com.lifequest.user.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
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
 */
@Service
public class QuestAssignmentService {

    private final UserDailyQuestRepository userDailyQuestRepository;
    private final QuestRepository questRepository;
    private final UserRepository userRepository;
    private final QuestUnlockPolicy questUnlockPolicy;
    private final QuestAssignmentCreator questAssignmentCreator;
    private final Clock clock;

    public QuestAssignmentService(UserDailyQuestRepository userDailyQuestRepository,
                                  QuestRepository questRepository,
                                  UserRepository userRepository,
                                  QuestUnlockPolicy questUnlockPolicy,
                                  QuestAssignmentCreator questAssignmentCreator,
                                  Clock clock) {
        this.userDailyQuestRepository = userDailyQuestRepository;
        this.questRepository = questRepository;
        this.userRepository = userRepository;
        this.questUnlockPolicy = questUnlockPolicy;
        this.questAssignmentCreator = questAssignmentCreator;
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
    public List<UserDailyQuest> getTodayQuests(Long userId) {
        LocalDateTime now = LocalDateTime.now(clock);
        List<UserDailyQuest> assigned =
            userDailyQuestRepository.findByUserIdAndExpiresAtAfter(userId, now);

        int level = userRepository.findById(userId)
            .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND))
            .getLevel();

        Set<QuestCadence> assignedCadences = assignedCadences(assigned);
        for (QuestCadence cadence : QuestCadence.values()) {
            if (!questUnlockPolicy.isUnlocked(level, feature(cadence))) {
                continue;
            }
            if (assignedCadences.contains(cadence)) {
                continue;
            }
            questAssignmentCreator.createForTrack(userId, cadence);
        }

        return userDailyQuestRepository.findByUserIdAndExpiresAtAfter(userId, now);
    }

    /**
     * 배정된 퀘스트들이 어느 트랙에 속하는지.
     *
     * <p>{@code UserDailyQuest}에 트랙 컬럼이 없어 {@code questId}로 원본을 봐야 한다. 배정 건이
     * 트랙당 3개씩 최대 6개뿐이라 조회 한 번으로 충분하며, 이 때문에 비정규화 컬럼을 두지 않는다.
     */
    private Set<QuestCadence> assignedCadences(List<UserDailyQuest> assigned) {
        if (assigned.isEmpty()) {
            return Set.of();
        }
        List<Long> questIds = new ArrayList<>();
        for (UserDailyQuest userDailyQuest : assigned) {
            questIds.add(userDailyQuest.getQuestId());
        }

        Set<QuestCadence> cadences = new HashSet<>();
        for (Quest quest : questRepository.findAllById(questIds)) {
            cadences.add(quest.getCadence());
        }
        return cadences;
    }

    /**
     * 트랙에 대응하는 잠금 기능. 협동은 {@link QuestCadence}에 없으므로 여기 나타나지 않는다 —
     * 두 enum의 값 집합이 어긋나는 것은 의도된 것이다.
     */
    private QuestFeature feature(QuestCadence cadence) {
        return cadence == QuestCadence.WEEKLY ? QuestFeature.WEEKLY : QuestFeature.DAILY;
    }
}
