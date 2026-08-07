package com.lifequest.quest.service;

import com.lifequest.collection.CollectionOutcome;
import com.lifequest.collection.CollectionService;
import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.growth.GrowthResult;
import com.lifequest.growth.GrowthService;
import com.lifequest.growth.GrowthSnapshot;
import com.lifequest.quest.domain.CompletionType;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.domain.QuestCompletion;
import com.lifequest.quest.domain.UserDailyQuest;
import com.lifequest.quest.dto.QuestCompletionRequest;
import com.lifequest.quest.dto.QuestCompletionResponse;
import com.lifequest.quest.repository.QuestCompletionRepository;
import com.lifequest.quest.repository.QuestRepository;
import com.lifequest.quest.repository.UserDailyQuestRepository;
import com.lifequest.profile.TitleAwardService;
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.text.MessageFormat;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.Optional;

import static org.springframework.transaction.annotation.Isolation.READ_COMMITTED;

@Service
@Transactional(isolation = READ_COMMITTED)
class QuestCompletionServiceImpl implements QuestCompletionService {
    private final UserDailyQuestRepository userDailyQuestRepository;
    private final QuestRepository questRepository;
    private final QuestCompletionRepository questCompletionRepository;
    private final GrowthService growthService;
    private final CollectionService collectionService;
    private final Clock clock;
    private final UserRepository userRepository;
    private final TitleAwardService titleAwardService;

    QuestCompletionServiceImpl(
        UserDailyQuestRepository userDailyQuestRepository,
        QuestRepository questRepository,
        QuestCompletionRepository questCompletionRepository,
        GrowthService growthService,
        CollectionService collectionService,
        Clock clock,
        UserRepository userRepository,
        TitleAwardService titleAwardService) {
        this.userDailyQuestRepository = userDailyQuestRepository;
        this.questRepository = questRepository;
        this.questCompletionRepository = questCompletionRepository;
        this.growthService = growthService;
        this.collectionService = collectionService;
        this.clock = clock;
        this.userRepository = userRepository;
        this.titleAwardService = titleAwardService;
    }

    private static boolean checkAccuracy(QuestCompletionRequest request, Quest quest) {
        if (!request.hasLocation()) {
            throw new BusinessException(ErrorCode.LOCATION_REQUIRED);
        }

        if (!request.isCoordinatesValid()) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }

        int minAccuracy = Math.min(quest.getRadiusM(), 100);
        boolean checkAccuracy =
            request.accuracy().compareTo(BigDecimal.ZERO) <= 0 ||
                request.accuracy().compareTo(BigDecimal.valueOf(minAccuracy)) > 0;
        if (checkAccuracy) {
            throw new BusinessException(ErrorCode.LOCATION_ACCURACY_TOO_LOW);
        }

        return true;
    }

    @Override
    public QuestCompletionResponse complete(Long requestUserId, Long dailyQuestId, QuestCompletionRequest request) {
        Objects.requireNonNull(request);
        LocalDateTime now = LocalDateTime.now(clock);

        // 비관적 락이 선행되어야함.
        UserDailyQuest userDailyQuest = userDailyQuestRepository.findByIdForUpdate(dailyQuestId)
            .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));

        if (!userDailyQuest.getUserId().equals(requestUserId)) {
            throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        }

        Quest quest = questRepository.findById(userDailyQuest.getQuestId())
            .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));

        Optional<QuestCompletion> checkQuestCompletion = questCompletionRepository.findByUserDailyQuestId(userDailyQuest.getId());
        if (checkQuestCompletion.isPresent()) {
            User user = userRepository.findById(requestUserId)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
            QuestCompletion questCompletion = checkQuestCompletion.get();
            return new QuestCompletionResponse(
                questCompletion.getId(),
                userDailyQuest.getId(),
                userDailyQuest.getQuestId(),
                quest.getGrade(),
                questCompletion.getCompletedAt(),
                true,
                isLocationType(quest) ?
                    new QuestCompletionResponse.Location(questCompletion.getDistanceM(), questCompletion.getAccuracyM()) : null,
                QuestCompletionResponse.noGrowth(user.getTotalExp(), user.getLevel()),
                QuestCompletionResponse.nothingCollected());
        }

        if (now.isAfter(userDailyQuest.getExpiresAt())) {
            throw new BusinessException(ErrorCode.QUEST_EXPIRED);
        }

        BigDecimal reportedLatitude = null;
        BigDecimal reportedLongitude = null;
        BigDecimal distanceM = null;
        BigDecimal accuracyM = null;
        if (quest.getCompletionType() == CompletionType.LOCATION &&
            checkAccuracy(request, quest)) {
            reportedLatitude = request.latitude();
            reportedLongitude = request.longitude();
            accuracyM = request
                .accuracy()
                .setScale(2, RoundingMode.HALF_UP);
            distanceM = BigDecimal.valueOf(
                    calculateDistance(
                        reportedLatitude.doubleValue(),
                        reportedLongitude.doubleValue(),
                        quest.getLatitude().doubleValue(),
                        quest.getLongitude().doubleValue()))
                .setScale(2, RoundingMode.HALF_UP);

            if (distanceM.compareTo(BigDecimal.valueOf(quest.getRadiusM())) > 0) {
                throw new BusinessException(
                    ErrorCode.OUT_OF_RADIUS,
                    MessageFormat.format(
                        "{0}\n 반경: {1}m\n 현재: {2}m",
                        ErrorCode.OUT_OF_RADIUS.message(), quest.getRadiusM(), distanceM
                    ));
            }
        }

        QuestCompletion questCompletion = questCompletionRepository.save(
            new QuestCompletion(
                userDailyQuest,
                reportedLatitude,
                reportedLongitude,
                distanceM,
                accuracyM,
                now
            ));
        userDailyQuest.markCompleted();

        GrowthResult growthResult = growthService.grantExp(
            requestUserId, "QUEST_COMPLETION", questCompletion.getId(), quest.getExpReward());

        GrowthSnapshot growthSnapshot = growthService.getGrowthById(requestUserId);

        // 이 호출은 완료 트랜잭션 안에 있다 — 구현체가 예외를 던지면 위의 QuestCompletion 기록과
        // EXP 지급까지 롤백된다(CollectionService javadoc 계약 ①). 아래 growth.rewards는
        // growthResult.rewards()(레벨업 보상)만 채운다. 업적 단계 보상은 완료 응답에 싣지 않기로
        // 했으므로 여기서 합치지 않는다(계약 ②) — CollectionOutcome은 해금 여부만 나른다.
        CollectionOutcome collectionOutcome = collectionService.evaluateOnQuestCompletion(
            requestUserId, quest.getId(), quest.getLifedexItemId(), questCompletion.getId());

        var rewards = new ArrayList<>(growthResult.rewards());
        rewards.addAll(titleAwardService.grantEligibleTitles(
            requestUserId, questCompletion.getId()));

        return new QuestCompletionResponse(
            questCompletion.getId(),
            userDailyQuest.getId(),
            quest.getId(),
            quest.getGrade(),
            now,
            false,
            isLocationType(quest) ?
                new QuestCompletionResponse.Location(distanceM, accuracyM) : null,
            new QuestCompletionResponse.Growth(
                growthResult.expGained(),
                growthSnapshot.totalExp(),
                growthResult.previousLevel(),
                growthResult.currentLevel(),
                growthResult.levelUp(),
                List.copyOf(rewards)),
            toCollectionResult(collectionOutcome));
    }

    private static QuestCompletionResponse.CollectionResult toCollectionResult(CollectionOutcome outcome) {
        return new QuestCompletionResponse.CollectionResult(
            outcome.newLifedexItems().stream().map(QuestCompletionServiceImpl::toEntry).toList(),
            outcome.newAchievements().stream().map(QuestCompletionServiceImpl::toEntry).toList());
    }

    private static QuestCompletionResponse.Entry toEntry(CollectionOutcome.Entry entry) {
        return new QuestCompletionResponse.Entry(
            entry.id(), entry.name(), entry.secret(), entry.reward());
    }

    private double calculateDistance(
        double reportedLat, double reportedLon,  // 요청자가 제공한 위치
        double targetLat, double targetLon     // 퀘스트가 지정한 위치
    ) {
        final double EARTH_RADIUS_M = 6371000;

        // 라디안으로 변환
        double reportedLatRad = Math.toRadians(reportedLat);
        double reportedLonRad = Math.toRadians(reportedLon);
        double targetLatRad = Math.toRadians(targetLat);
        double targetLonRad = Math.toRadians(targetLon);

        // 위도·경도 차이(라디안)
        double deltaLatRad = reportedLatRad - targetLatRad;
        double deltaLonRad = reportedLonRad - targetLonRad;

        // 삼각함수 중간값 계산
        double sinDeltaLatHalf = Math.sin(deltaLatRad / 2);
        double sinDeltaLonHalf = Math.sin(deltaLonRad / 2);
        double cosReportedLat = Math.cos(reportedLatRad);
        double cosTargetLat = Math.cos(targetLatRad);

        // Haversine 공식의 a 값
        // a = sin²(Δlat/2) + cos(lat₁)·cos(lat₂)·sin²(Δlon/2)
        double a = sinDeltaLatHalf * sinDeltaLatHalf +
            cosReportedLat * cosTargetLat *
                sinDeltaLonHalf * sinDeltaLonHalf;

        // 중심각(라디안)
        // c = 2·atan2(√a, √(1-a))
        double centralAngleRad = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

        // 거리(미터)
        return EARTH_RADIUS_M * centralAngleRad;
    }

    private boolean isLocationType(Quest quest) {
        return quest.getCompletionType() == CompletionType.LOCATION;
    }
}
