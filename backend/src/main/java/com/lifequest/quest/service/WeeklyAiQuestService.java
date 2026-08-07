package com.lifequest.quest.service;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.domain.QuestFeature;
import com.lifequest.quest.domain.UserDailyQuest;
import com.lifequest.quest.domain.WeeklyAiQuestClaim;
import com.lifequest.quest.dto.DailyQuestResponse;
import com.lifequest.quest.repository.QuestRepository;
import com.lifequest.quest.repository.UserDailyQuestRepository;
import com.lifequest.quest.repository.WeeklyAiQuestClaimRepository;
import com.lifequest.recommendation.WeeklyRecommendationCandidate;
import com.lifequest.recommendation.WeeklyRecommendationCandidateRepository;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Locale;

/**
 * 사용자가 고른 AI 추천을 주간 슬롯 C에 넣는다(docs/05-business-rules.md §1-A).
 *
 * <h2>claim을 가장 먼저 INSERT한다</h2>
 * V19가 배정 마커에 대해 적은 것과 같은 이유다. "이미 받았는가"를 조회로 판정하면 두 요청이 모두
 * "없음"을 보는 창이 남고, 그 사이에 각각 퀘스트를 만들면 한 주에 AI 퀘스트가 둘이 된다.
 * 판정 주체를 애플리케이션 조회가 아니라 DB 제약으로 두면 인스턴스를 늘려도 무력화되지 않는다.
 *
 * <p><b>{@code saveAndFlush}여야 한다.</b> {@code save}만 하면 INSERT가 커밋까지 미뤄져 위반을
 * 그 자리에서 잡을 수 없다.
 *
 * <p>claim이 먼저 들어간 뒤 후보 검증이 실패해도 같은 트랜잭션이라 전부 롤백된다 — 반쪽짜리
 * claim이 남아 그 주를 통째로 막는 일은 없다. 여기서 {@code REQUIRES_NEW}를 쓰지 않는 것이
 * 마커와 다른 점이며, 마커는 <b>실패해도 남아야</b> 하지만 claim은 그 반대다.
 *
 * <h2>유니크 위반을 원인별로 갈라야 한다</h2>
 * 제약이 둘이고 사용자에게 할 말이 다르다. 뭉뚱그려 "이미 받음"으로 처리하면, 남의 후보 id를
 * 찍어본 사용자에게 "이번 주 AI 퀘스트는 이미 받았습니다"라는 엉뚱한 안내가 나간다.
 */
@Service
public class WeeklyAiQuestService {

    private final WeeklyAiQuestClaimRepository claimRepository;
    private final WeeklyRecommendationCandidateRepository candidateRepository;
    private final QuestRepository questRepository;
    private final UserDailyQuestRepository userDailyQuestRepository;
    private final QuestUnlockPolicy questUnlockPolicy;
    private final WeeklyAiQuestSlot weeklyAiQuestSlot;
    private final QuestPeriod questPeriod;
    private final Clock clock;

    public WeeklyAiQuestService(WeeklyAiQuestClaimRepository claimRepository,
                                WeeklyRecommendationCandidateRepository candidateRepository,
                                QuestRepository questRepository,
                                UserDailyQuestRepository userDailyQuestRepository,
                                QuestUnlockPolicy questUnlockPolicy,
                                WeeklyAiQuestSlot weeklyAiQuestSlot,
                                QuestPeriod questPeriod,
                                Clock clock) {
        this.claimRepository = claimRepository;
        this.candidateRepository = candidateRepository;
        this.questRepository = questRepository;
        this.userDailyQuestRepository = userDailyQuestRepository;
        this.questUnlockPolicy = questUnlockPolicy;
        this.weeklyAiQuestSlot = weeklyAiQuestSlot;
        this.questPeriod = questPeriod;
        this.clock = clock;
    }

    /**
     * 후보 하나를 이번 주 AI 퀘스트로 확정한다.
     *
     * <p>사용자 행을 잠그지 않는다. 주당 1회를 보장하는 것은
     * {@code uk_weekly_ai_claim_period}이지 애플리케이션 락이 아니며, 락은 다중 인스턴스에서
     * 그 성질을 잃는다. 레벨은 잠금 없이 읽어도 충분하다 — 검사 직후 강등되는 경로가 없다.
     *
     * @return 만들어진 배정. 목록 응답의 항목과 같은 모양이라 앱이 그대로 끼워 넣을 수 있다
     */
    @Transactional
    public DailyQuestResponse claim(Long userId, Long candidateId) {
        if (candidateId == null) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        questUnlockPolicy.requireUnlocked(userId, QuestFeature.WEEKLY);

        // 슬롯이 열려 있는지는 추천 경로와 같은 판정을 쓴다. 여기에만 있으면 이미 받은
        // 사용자가 LLM 비용을 계속 쓰고, 추천 경로에만 있으면 API를 직접 부르는 길이 남는다.
        //
        // "주간 최대 3개"를 앱이 아니라 서버가 지키는 자리이기도 하다 — 앱은 자리가 없으면
        // 카드를 감추지만, 그것만으로는 요청을 직접 보내는 경로를 막지 못한다.
        WeeklyAiQuestSlot.Availability availability = weeklyAiQuestSlot.availability(userId);
        if (!availability.open()) {
            throw new BusinessException(availability.reason());
        }

        QuestPeriod.QuestLifePeriod period = questPeriod.create(QuestCadence.WEEKLY);
        LocalDate periodStart = period.getStartAt();
        LocalDateTime now = LocalDateTime.now(clock);

        // 후보 검증이 claim INSERT보다 먼저다.
        //
        // claim을 먼저 넣으면 없는 후보 id에서 FK(fk_waqc_candidate)가 먼저 터지고, 그 예외는
        // 유니크 위반과 같은 타입이라 "이번 주 이미 받음"으로 오분류된다 — 아무것도 받지 않은
        // 사용자가 409를 본다. 검증을 앞에 두면 FK가 깨질 경로 자체가 없어진다.
        //
        // 이 순서로도 주당 1회 보장은 그대로다. 판정은 여전히 아래 유니크 제약이 하고, 그것이
        // 퀘스트 생성보다 앞에 있다. 여기서 앞당긴 것은 "무엇이 잘못됐는지"를 가리는 일뿐이다.
        WeeklyRecommendationCandidate candidate = candidateRepository.findByIdForUpdate(candidateId)
            .orElseThrow(() -> new BusinessException(ErrorCode.RECOMMENDATION_CANDIDATE_NOT_FOUND));

        // 소유자 불일치는 "없음"과 같은 응답을 준다. 남의 후보 id를 찍어봤을 때 존재 여부가
        // 새면 안 된다 — 후보 제목에는 그 사용자가 입력한 지역·예산이 반영돼 있다.
        if (!candidate.belongsTo(userId)) {
            throw new BusinessException(ErrorCode.RECOMMENDATION_CANDIDATE_NOT_FOUND);
        }
        // 주기가 넘어간 후보다. NOT_FOUND로 뭉개면 화면에 후보가 보이는 채로 "찾을 수 없습니다"가
        // 떠서 버그로 읽힌다.
        if (!candidate.isForPeriod(periodStart)) {
            throw new BusinessException(ErrorCode.RECOMMENDATION_CANDIDATE_EXPIRED);
        }
        if (candidate.isClaimed()) {
            throw new BusinessException(ErrorCode.RECOMMENDATION_CANDIDATE_ALREADY_CLAIMED);
        }

        // 여기서부터가 쓰기다. 퀘스트·배정보다 claim이 먼저 들어가야 경합에서 진 요청이
        // 퀘스트를 만들어 두고 롤백되는 대신 제약에서 곧장 멈춘다.
        try {
            claimRepository.saveAndFlush(
                new WeeklyAiQuestClaim(userId, periodStart, candidateId, now));
        } catch (DataIntegrityViolationException e) {
            throw new BusinessException(causeOf(e));
        }

        Quest quest = questRepository.save(Quest.createPrivateAiWeekly(
            userId,
            candidate.getTitle(),
            candidate.getDescription(),
            candidate.getSuggestedPlaceName(),
            candidate.getCompletionGuide()));

        UserDailyQuest assignment = userDailyQuestRepository.save(
            new UserDailyQuest(userId, quest.getId(), periodStart, period.getExpiresAt()));

        candidate.markClaimed(now);

        return DailyQuestResponse.of(assignment, quest);
    }

    /**
     * 어느 제약이 깨졌는지 이름으로 가른다.
     *
     * <p>제약 이름이 예외 메시지 어딘가에 들어 있다는 사실에 기대는 방식이라 견고하지는 않다.
     * 다만 틀렸을 때의 결과가 "안내 문구가 덜 정확함"이고 <b>주당 1회 보장 자체는 제약이 이미
     * 지킨 뒤</b>라, 여기서 더 무겁게 갈 이유가 없다. 이름을 못 찾으면 흔한 쪽인 주당 1회로 본다.
     */
    private ErrorCode causeOf(DataIntegrityViolationException e) {
        String message = String.valueOf(e.getMostSpecificCause().getMessage()).toLowerCase(Locale.ROOT);
        return message.contains("uk_weekly_ai_claim_candidate")
            ? ErrorCode.RECOMMENDATION_CANDIDATE_ALREADY_CLAIMED
            : ErrorCode.WEEKLY_AI_QUEST_ALREADY_CLAIMED;
    }
}
