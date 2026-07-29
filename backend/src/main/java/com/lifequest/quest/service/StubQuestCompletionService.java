package com.lifequest.quest.service;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.growth.RewardGrant;
import com.lifequest.quest.domain.QuestGrade;
import com.lifequest.quest.dto.QuestCompletionRequest;
import com.lifequest.quest.dto.QuestCompletionResponse;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

/**
 * 완료 API의 <b>임시</b> 구현. 계약이 정한 응답 모양과 오류 분기를 흉내 낼 뿐,
 * 실제 완료 기록·성장·수집은 일어나지 않는다.
 *
 * <p>있는 이유는 팀원이 완료 화면의 분기 UI(중복 완료·반경 밖·만료·정확도)를 만들려면
 * 각 응답을 실제로 받아 볼 수 있어야 하기 때문이다. 계약이
 * {@code docs/04-api-spec.md} §4에 이미 확정돼 있으므로 이 스텁은 계약을 발명하지 않고
 * 구현만 한다 — 여기에 맞춰 만든 클라이언트가 실구현에서 깨지지 않는다.
 *
 * <h2>회수 장치</h2>
 *
 * 이 레포에는 회수 장치 없는 스텁이 살아남아 마이페이지 완료 수가 영구 0이 된 전례가
 * 있다({@code UserController.java}의 {@code questHistory}). 그래서 잊어도 드러나도록 만든다.
 *
 * <ul>
 *   <li>클래스명에 {@code Stub} — {@code rg Stub} 로 즉시 찾힌다
 *   <li>{@link Profile @Profile("!prod")} — 실구현 없이 prod 로 뜨면 주입할 빈이 없어
 *       <b>기동 자체가 실패한다.</b> 회수를 잊는 것이 구조적으로 불가능하다
 *   <li>응답 헤더 {@code X-Stub: true} — 받는 쪽이 실제 동작으로 오해하지 않는다
 *   <li>인터페이스 분리 — 실구현이 오면 이 클래스를 삭제하기만 하면 된다
 * </ul>
 *
 * <h2>시나리오 규약 (스텁 전용)</h2>
 *
 * 배정 ID로 분기를 고른다. 실구현에는 남지 않는 임시 규약이다.
 *
 * <ul>
 *   <li><b>9001</b> — {@code QUEST_EXPIRED}
 *   <li><b>9002</b> — {@code OUT_OF_RADIUS}. 현재 거리를 메시지에 싣는다
 *   <li><b>9003</b> — 위치 인증 퀘스트로 취급. 좌표가 없으면 {@code LOCATION_REQUIRED}
 *   <li><b>9004</b> — 정상 완료 + 레벨업 + <b>비밀 업적</b> 해금(모달 확인용)
 *   <li><b>그 외</b> — 정상 완료
 * </ul>
 *
 * 좌표를 보낸 경우 정확도가 {@value #ACCURACY_LIMIT_M}m 를 넘으면
 * {@code LOCATION_ACCURACY_TOO_LOW} 다. 어떤 ID든 <b>두 번째 호출부터</b>는
 * {@code duplicated=true} 이고 아무것도 재지급하지 않는다.
 */
@Service
@Profile("!prod")
public class StubQuestCompletionService implements QuestCompletionService {

    /** 스텁 임계값. 실구현은 규칙서(`05-business-rules.md` §3)의 값을 따른다. */
    static final int ACCURACY_LIMIT_M = 50;

    private static final long EXPIRED_ID = 9001L;
    private static final long OUT_OF_RADIUS_ID = 9002L;
    private static final long LOCATION_REQUIRED_ID = 9003L;
    private static final long SECRET_ACHIEVEMENT_ID = 9004L;

    /** 배정 ID → 첫 완료 결과. 두 번째 호출은 여기서 꺼내 그대로 돌려준다. */
    private final Map<Long, QuestCompletionResponse> completed = new ConcurrentHashMap<>();
    private final AtomicLong completionIds = new AtomicLong(4800L);

    @Override
    public QuestCompletionResponse complete(
            Long userId, Long dailyQuestId, QuestCompletionRequest request) {

        // 계약 순서를 지킨다 — 기존 완료 기록을 위치 검증보다 먼저 본다.
        // 반경 밖으로 이동한 뒤 다시 눌러도 이미 받은 완료가 오류가 되어서는 안 된다.
        QuestCompletionResponse first = completed.get(dailyQuestId);
        if (first != null) {
            return duplicateOf(first);
        }

        if (dailyQuestId == EXPIRED_ID) {
            throw new BusinessException(ErrorCode.QUEST_EXPIRED);
        }

        if (dailyQuestId == LOCATION_REQUIRED_ID && !request.hasLocation()) {
            throw new BusinessException(ErrorCode.LOCATION_REQUIRED);
        }

        if (request.hasLocation()) {
            if (request.accuracy().compareTo(BigDecimal.valueOf(ACCURACY_LIMIT_M)) > 0) {
                throw new BusinessException(ErrorCode.LOCATION_ACCURACY_TOO_LOW);
            }
            if (dailyQuestId == OUT_OF_RADIUS_ID) {
                // 계약이 "반경 밖"만이 아니라 현재 거리까지 요구한다. 앱은 이 코드에서
                // 서버 메시지가 있으면 그대로 보여준다.
                throw new BusinessException(
                        ErrorCode.OUT_OF_RADIUS, "아직 132m 떨어져 있어요. 조금 더 가까이 가 주세요.");
            }
        }

        QuestCompletionResponse response = newCompletion(dailyQuestId, request);
        completed.put(dailyQuestId, response);
        return response;
    }

    private QuestCompletionResponse newCompletion(
            Long dailyQuestId, QuestCompletionRequest request) {
        boolean secret = dailyQuestId == SECRET_ACHIEVEMENT_ID;
        return new QuestCompletionResponse(
                completionIds.incrementAndGet(),
                dailyQuestId,
                12L,
                secret ? QuestGrade.EPIC : QuestGrade.RARE,
                LocalDateTime.now(),
                false,
                request.hasLocation()
                        ? new QuestCompletionResponse.Location(
                                new BigDecimal("23.40"), request.accuracy())
                        : null,
                secret
                        ? new QuestCompletionResponse.Growth(
                                80,
                                430,
                                4,
                                5,
                                true,
                                List.of(new RewardGrant(
                                        "TITLE", "NEIGHBORHOOD_EXPLORER", "동네 탐험가")))
                        : new QuestCompletionResponse.Growth(30, 350, 5, 5, false, List.of()),
                secret
                        ? new QuestCompletionResponse.CollectionResult(
                                List.of(new QuestCompletionResponse.Entry(12L, "첫 카페 탐험", false)),
                                List.of(new QuestCompletionResponse.Entry(31L, "새벽의 방문자", true)))
                        : QuestCompletionResponse.nothingCollected());
    }

    /**
     * 두 번째 호출의 응답. 같은 {@code completionId} 를 돌려주되 성장·수집은 비운다 —
     * 계약이 정한 "재지급 없음"의 모양은 {@link QuestCompletionResponse} 쪽에 모아 뒀다.
     */
    private QuestCompletionResponse duplicateOf(QuestCompletionResponse first) {
        return new QuestCompletionResponse(
                first.completionId(),
                first.dailyQuestId(),
                first.questId(),
                first.grade(),
                first.completedAt(),
                true,
                first.location(),
                QuestCompletionResponse.noGrowth(
                        first.growth().totalExp(), first.growth().currentLevel()),
                QuestCompletionResponse.nothingCollected());
    }
}
