package com.lifequest.recommendation;

import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.domain.QuestFeature;
import com.lifequest.quest.service.QuestPeriod;
import com.lifequest.quest.service.QuestUnlockPolicy;
import com.lifequest.recommendation.dto.PlaceQuestRecommendationRequest;
import com.lifequest.recommendation.dto.QuestRecommendationResponse;
import com.lifequest.recommendation.dto.TravelQuestRecommendationRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;

/**
 * 주간 퀘스트 슬롯을 채우기 위한 추천(docs/05-business-rules.md §1-A).
 *
 * <p>일반 추천({@link QuestRecommendationService#place}·{@code travel})과 두 가지가 다르다.
 * <ol>
 *   <li><b>후보를 저장한다.</b> 선택의 대상이 되어야 하므로 id가 필요하다. 일반 추천은 저장하지
 *       않는다 — 구경만 하는 요청까지 쌓으면 후보 테이블이 쓰이지 않을 행으로 채워진다.
 *   <li><b>여행 기간이 그 주의 남은 일수로 제한된다.</b> 일반 여행 추천은 계속 14일까지 지원한다.
 * </ol>
 */
@Service
public class WeeklyQuestRecommendationService {

    /** 주간 트랙의 한 주기 길이(일). {@link QuestPeriod}가 만료를 시작일+7일로 잡는다. */
    private static final int WEEKLY_PERIOD_DAYS = 7;

    private final QuestRecommendationService recommendations;
    private final QuestRecommendationPromptFactory prompts;
    private final WeeklyRecommendationCandidateRepository candidates;
    private final QuestUnlockPolicy questUnlockPolicy;
    private final QuestPeriod questPeriod;
    private final Clock clock;

    public WeeklyQuestRecommendationService(QuestRecommendationService recommendations,
                                            QuestRecommendationPromptFactory prompts,
                                            WeeklyRecommendationCandidateRepository candidates,
                                            QuestUnlockPolicy questUnlockPolicy,
                                            QuestPeriod questPeriod,
                                            Clock clock) {
        this.recommendations = recommendations;
        this.prompts = prompts;
        this.candidates = candidates;
        this.questUnlockPolicy = questUnlockPolicy;
        this.questPeriod = questPeriod;
        this.clock = clock;
    }

    @Transactional
    public QuestRecommendationResponse place(Long userId, PlaceQuestRecommendationRequest request) {
        // Lv.3 검사가 사용량 차감보다 먼저다. 뒤에 두면 Lv.2 사용자가 받을 수도 없는 추천 때문에
        // 하루 10회 중 1회를 잃고, 선택 단계에 가서야 QUEST_FEATURE_LOCKED을 만난다.
        questUnlockPolicy.requireUnlocked(userId, QuestFeature.WEEKLY);
        recommendations.validatePlace(request);

        return store(userId, recommendations.run(
            userId,
            prompts.weeklyPlace(request, remainingDays()),
            new RecommendationConstraints(
                RecommendationType.PLACE, request.budgetPerPerson(), request.availableMinutes())));
    }

    @Transactional
    public QuestRecommendationResponse travel(Long userId, TravelQuestRecommendationRequest request) {
        questUnlockPolicy.requireUnlocked(userId, QuestFeature.WEEKLY);

        // 주간 만료는 "받은 날 + 7일"이 아니라 그 주 월요일 04:00 + 7일 고정이다. 토요일에 받은
        // 7일짜리 여행은 시작부터 이틀 뒤 만료라, 기간 상한을 14일도 7일도 아닌 남은 일수로 둔다.
        int remainingDays = remainingDays();
        recommendations.validateTravel(request, remainingDays);

        return store(userId, recommendations.run(
            userId,
            prompts.weeklyTravel(request, remainingDays),
            new RecommendationConstraints(
                RecommendationType.TRAVEL, request.budgetPerPerson(), request.days())));
    }

    /**
     * 이번 주기에 남은 일수. 최소 1이다.
     *
     * <p><b>시각이 아니라 논리적 일자로 센다.</b> {@code ChronoUnit.DAYS.between(now, expiresAt)}은
     * 실제 경과 시간을 내림하므로 논리적 월요일 05:00에 이미 6을 준다 — 매일 하루씩 적게 나오고
     * 04:00 경계에서 또 어긋난다. 주기 경계가 04:00 오프셋으로 정의돼 있으므로
     * ({@link QuestPeriod#logicalDate()}) 같은 기준으로 세야 한다.
     *
     * <p>월 7 · 목 4 · 토 2 · 일 1.
     */
    int remainingDays() {
        QuestPeriod.QuestLifePeriod period = questPeriod.create(QuestCadence.WEEKLY);
        long elapsed = ChronoUnit.DAYS.between(period.getStartAt(), questPeriod.logicalDate());
        return Math.max(1, Math.toIntExact(WEEKLY_PERIOD_DAYS - elapsed));
    }

    /**
     * 검증을 통과한 후보를 저장하고 id가 채워진 응답을 만든다.
     *
     * <p>{@code index}는 저장 순서와 같게 유지한다 — 앱이 "1. …" 로 표시하는 번호이고, 선택은
     * {@code candidateId}로 하므로 둘이 어긋나면 사용자가 고른 것과 다른 퀘스트가 들어간다.
     */
    private QuestRecommendationResponse store(Long userId, QuestRecommendationService.Generated generated) {
        LocalDateTime now = LocalDateTime.now(clock);
        var periodStart = questPeriod.create(QuestCadence.WEEKLY).getStartAt();

        List<QuestRecommendationCandidate> stored = new ArrayList<>();
        int index = 1;
        for (QuestRecommendationCandidate candidate : generated.candidates()) {
            WeeklyRecommendationCandidate saved = candidates.save(
                new WeeklyRecommendationCandidate(userId, periodStart, candidate, now));
            stored.add(saved.toResponse(index++));
        }

        return QuestRecommendationService.toResponse(new QuestRecommendationService.Generated(
            generated.provider(), generated.model(), generated.remaining(), stored));
    }
}
