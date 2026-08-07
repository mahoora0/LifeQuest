package com.lifequest.recommendation;

import com.lifequest.recommendation.dto.QuestRecommendationResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * 주간 추천 후보의 쓰기 담당.
 *
 * <h2>왜 별도 빈인가</h2>
 * 추천 생성은 <b>외부 LLM HTTP 호출</b>을 포함한다. 그 호출까지 트랜잭션 안에 들어가면 응답을
 * 기다리는 내내 DB 커넥션이 묶인다 — 주간 추천이 몇 개만 동시에 들어와도 커넥션 풀이 차서
 * 추천과 무관한 API까지 대기한다. LLM 응답은 초 단위이고 타임아웃 기본값이 30초라, 커넥션을
 * 붙잡는 시간이 일반 요청의 수백 배가 된다.
 *
 * <p>그래서 {@link WeeklyQuestRecommendationService}는 트랜잭션 없이 흘러가고, DB에 실제로
 * 쓰는 이 구간만 트랜잭션을 연다. <b>같은 빈의 private 메서드에 어노테이션을 붙이는 것으로는
 * 안 된다</b> — 자기호출은 프록시를 거치지 않아 어노테이션이 통째로 무시된다
 * ({@code QuestAssignmentCreator}가 같은 함정을 문서화하고 있다).
 *
 * <p>트랜잭션이 짧아지면서 잃는 것은 "후보 3건이 한 트랜잭션에 들어간다" 정도인데, 부분 저장이
 * 생겨도 각 행이 독립적으로 유효하고 선택은 id 단위라 문제가 되지 않는다.
 */
@Service
public class WeeklyRecommendationCandidateStore {

    /**
     * 후보를 남겨 두는 주기 수. 이번 주기와 직전 {@code KEEP_PERIODS - 1}주기까지 보관한다.
     *
     * <p>지난 주기 후보는 선택할 수 없다({@code RECOMMENDATION_CANDIDATE_EXPIRED}). 그래도 바로
     * 지우지 않는 것은 "왜 못 고르지"를 확인할 근거를 조금 남겨 두기 위해서다. 4주면 문의가
     * 들어올 만한 기간을 덮고, 사용자당 최대 30행/일이라 양도 문제되지 않는다.
     */
    static final int KEEP_PERIODS = 4;

    private final WeeklyRecommendationCandidateRepository candidates;
    private final Clock clock;

    public WeeklyRecommendationCandidateStore(WeeklyRecommendationCandidateRepository candidates,
                                              Clock clock) {
        this.candidates = candidates;
        this.clock = clock;
    }

    /**
     * 검증을 통과한 후보를 저장하고 id가 채워진 응답을 만든다.
     *
     * <p>{@code index}는 저장 순서와 같게 유지한다 — 앱이 "1. …"로 표시하는 번호이고 선택은
     * {@code candidateId}로 하므로, 둘이 어긋나면 사용자가 고른 것과 다른 퀘스트가 들어간다.
     *
     * <p>저장 전에 그 사용자의 오래된 후보를 지운다. 아래 {@code purgeStale} 참조.
     */
    @Transactional
    public QuestRecommendationResponse store(Long userId, LocalDate periodStart,
                                             QuestRecommendationService.Generated generated) {
        purgeStale(userId, periodStart);

        LocalDateTime now = LocalDateTime.now(clock);
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

    /**
     * 그 사용자의 오래된 <b>미선택</b> 후보를 지운다.
     *
     * <h2>왜 스케줄러가 아닌가</h2>
     * 이 저장소는 배치 스케줄러를 두지 않는 쪽을 택했다(V19: "배치 스케줄러를 두지 않으므로 새
     * 장애점이 생기지 않는다"). 배정이 지연 생성이듯 정리도 지연 정리로 맞춘다 — 추천을 새로
     * 받는 그 요청이 자기 몫만 치운다. 작업량이 한 사용자 분량으로 묶여 있어 커지지 않고,
     * 새 인프라도 새 실패 지점도 생기지 않는다.
     *
     * <p><b>선택된 후보는 남긴다.</b> {@code weekly_ai_quest_claims.candidate_id}가 FK로 걸려
     * 있어 지우면 제약 위반이고, 애초에 claim은 "그 주에 다시 못 받는다"의 근거라 지우면 안 된다.
     * 선택분은 사용자당 주 1건뿐이라 쌓여도 무시할 수 있는 양이다.
     */
    private void purgeStale(Long userId, LocalDate periodStart) {
        candidates.deleteStaleUnclaimed(userId, periodStart.minusWeeks(KEEP_PERIODS - 1L));
    }
}
