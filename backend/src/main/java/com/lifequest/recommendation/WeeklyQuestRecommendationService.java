package com.lifequest.recommendation;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.domain.QuestFeature;
import com.lifequest.quest.service.QuestPeriod;
import com.lifequest.quest.service.QuestUnlockPolicy;
import com.lifequest.quest.service.WeeklyAiQuestSlot;
import com.lifequest.recommendation.dto.PlaceQuestRecommendationRequest;
import com.lifequest.recommendation.dto.QuestRecommendationResponse;
import com.lifequest.recommendation.dto.TravelQuestRecommendationRequest;
import org.springframework.stereotype.Service;

import java.time.temporal.ChronoUnit;

/**
 * 주간 퀘스트 슬롯을 채우기 위한 추천(docs/05-business-rules.md §1-A·§1-D).
 *
 * <p>일반 추천({@link QuestRecommendationService#place}·{@code travel})과 세 가지가 다르다.
 * <ol>
 *   <li><b>후보를 저장한다.</b> 선택의 대상이 되어야 하므로 id가 필요하다. 일반 추천은 저장하지
 *       않는다 — 구경만 하는 요청까지 쌓으면 후보 테이블이 쓰이지 않을 행으로 채워진다.
 *   <li><b>여행 기간이 그 주의 남은 일수로 제한된다.</b> 일반 여행 추천은 계속 14일까지 지원한다.
 *   <li><b>이번 주 슬롯이 열려 있어야 한다.</b> 아래 참조.
 * </ol>
 *
 * <h2>이 클래스에 {@code @Transactional}을 붙이지 않는다</h2>
 * 여기서 외부 LLM HTTP 호출이 일어난다. 메서드 전체를 트랜잭션으로 감싸면 응답을 기다리는 내내
 * DB 커넥션이 묶여, 주간 추천 몇 개만 동시에 들어와도 커넥션 풀이 차고 추천과 무관한 API까지
 * 대기한다. DB에 쓰는 구간만 {@link WeeklyRecommendationCandidateStore}가 별도 빈으로 맡는다.
 *
 * <h2>검사 순서 — 돈이 나가기 전에 전부 끝낸다</h2>
 * 사용량 차감({@code REQUIRES_NEW})은 LLM 호출이 실패해도 남는다. 한도를 우회하려 실패를
 * 반복하는 것을 막기 위한 설계라, <b>쓸 수 없는 추천으로 차감이 일어나면 안 된다.</b>
 * 잠금·슬롯·입력값 검증이 전부 {@code run()} 앞에 오는 이유다.
 */
@Service
public class WeeklyQuestRecommendationService {

    /** 주간 트랙의 한 주기 길이(일). {@link QuestPeriod}가 만료를 시작일+7일로 잡는다. */
    private static final int WEEKLY_PERIOD_DAYS = 7;

    private final QuestRecommendationService recommendations;
    private final QuestRecommendationPromptFactory prompts;
    private final WeeklyRecommendationCandidateStore store;
    private final QuestUnlockPolicy questUnlockPolicy;
    private final WeeklyAiQuestSlot weeklyAiQuestSlot;
    private final QuestPeriod questPeriod;

    public WeeklyQuestRecommendationService(QuestRecommendationService recommendations,
                                            QuestRecommendationPromptFactory prompts,
                                            WeeklyRecommendationCandidateStore store,
                                            QuestUnlockPolicy questUnlockPolicy,
                                            WeeklyAiQuestSlot weeklyAiQuestSlot,
                                            QuestPeriod questPeriod) {
        this.recommendations = recommendations;
        this.prompts = prompts;
        this.store = store;
        this.questUnlockPolicy = questUnlockPolicy;
        this.weeklyAiQuestSlot = weeklyAiQuestSlot;
        this.questPeriod = questPeriod;
    }

    public QuestRecommendationResponse place(Long userId, PlaceQuestRecommendationRequest request) {
        requireOpenSlot(userId);
        recommendations.validatePlace(request);

        return store.store(userId, periodStart(), recommendations.run(
            userId,
            prompts.weeklyPlace(request, remainingDays()),
            new RecommendationConstraints(
                RecommendationType.PLACE, request.budgetPerPerson(), request.availableMinutes())));
    }

    public QuestRecommendationResponse travel(Long userId, TravelQuestRecommendationRequest request) {
        requireOpenSlot(userId);

        // 주간 만료는 "받은 날 + 7일"이 아니라 그 주 월요일 04:00 + 7일 고정이다. 토요일에 받은
        // 7일짜리 여행은 시작부터 이틀 뒤 만료라, 기간 상한을 14일도 7일도 아닌 남은 일수로 둔다.
        int remainingDays = remainingDays();
        recommendations.validateTravel(request, remainingDays);

        return store.store(userId, periodStart(), recommendations.run(
            userId,
            prompts.weeklyTravel(request, remainingDays),
            new RecommendationConstraints(
                RecommendationType.TRAVEL, request.budgetPerPerson(), request.days())));
    }

    /** 앱이 진입 전에 물어보는 상태 — 슬롯이 열려 있는지와 이번 주에 남은 일수. */
    public WeeklyAiQuestStatus status(Long userId) {
        WeeklyAiQuestSlot.Availability availability = weeklyAiQuestSlot.availability(userId);
        return new WeeklyAiQuestStatus(
            availability.open(), availability.reason(), remainingDays());
    }

    /**
     * 슬롯이 열려 있는지 확인한다. <b>사용량 차감보다 먼저다.</b>
     *
     * <p>없으면 이미 받은 사용자가 추천을 계속 돌릴 수 있다 — LLM 비용과 하루 횟수를 쓰고
     * 마지막 선택에서야 409를 만난다. 실제 동시성 판정은 {@code uk_weekly_ai_claim_period}가
     * 그대로 하고, 이 조회는 <b>헛돈을 막는 사전 검사</b>다.
     */
    private void requireOpenSlot(Long userId) {
        questUnlockPolicy.requireUnlocked(userId, QuestFeature.WEEKLY);
        WeeklyAiQuestSlot.Availability availability = weeklyAiQuestSlot.availability(userId);
        if (!availability.open()) {
            throw new BusinessException(availability.reason());
        }
    }

    private java.time.LocalDate periodStart() {
        return questPeriod.create(QuestCadence.WEEKLY).getStartAt();
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
        long elapsed = ChronoUnit.DAYS.between(periodStart(), questPeriod.logicalDate());
        return Math.max(1, Math.toIntExact(WEEKLY_PERIOD_DAYS - elapsed));
    }
}
