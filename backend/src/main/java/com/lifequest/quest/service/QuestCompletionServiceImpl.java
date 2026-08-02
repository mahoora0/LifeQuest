package com.lifequest.quest.service;

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
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.text.MessageFormat;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Optional;

import static org.springframework.transaction.annotation.Isolation.READ_COMMITTED;

@Service
@Transactional(isolation = READ_COMMITTED)
class QuestCompletionServiceImpl implements QuestCompletionService {
    private final UserDailyQuestRepository userDailyQuestRepository;
    private final QuestRepository questRepository;
    private final QuestCompletionRepository questCompletionRepository;
    private final GrowthService growthService;
    private final Clock clock;
    private final UserRepository userRepository;

    private QuestCompletionServiceImpl(
        UserDailyQuestRepository userDailyQuestRepository,
        QuestRepository questRepository,
        QuestCompletionRepository questCompletionRepository,
        GrowthService growthService,
        Clock clock,
        UserRepository userRepository) {
        this.userDailyQuestRepository = userDailyQuestRepository;
        this.questRepository = questRepository;
        this.questCompletionRepository = questCompletionRepository;
        this.growthService = growthService;
        this.clock = clock;
        this.userRepository = userRepository;
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
        LocalDateTime now = LocalDateTime.now(clock);

        // 비관적 락이 선행되어야함.
        UserDailyQuest userDailyQuest = userDailyQuestRepository.findByIdForUpdate(dailyQuestId)
            .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));

        if (!userDailyQuest.getUserId().equals(requestUserId)) {
            throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        }

        User user = userRepository.findById(requestUserId)
            .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));

        Quest quest = questRepository.findById(userDailyQuest.getQuestId())
            .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));

        Optional<QuestCompletion> checkQuestCompletion = questCompletionRepository.findByUserDailyQuestId(userDailyQuest.getId());
        if (checkQuestCompletion.isPresent()) {
            QuestCompletion questCompletion = checkQuestCompletion.get();
            return new QuestCompletionResponse(
                questCompletion.getId(),
                userDailyQuest.getId(),
                userDailyQuest.getQuestId(),
                quest.getGrade(),
                questCompletion.getCompletedAt(),
                true,
                new QuestCompletionResponse.Location(questCompletion.getDistanceM(), questCompletion.getAccuracyM()),
                QuestCompletionResponse.noGrowth(user.getTotalExp(), user.getLevel()),
                QuestCompletionResponse.nothingCollected());
        }

        if (now.isAfter(userDailyQuest.getExpiresAt())) {
            throw new BusinessException(ErrorCode.QUEST_EXPIRED);
        }

        BigDecimal verifiedLatitude = null;
        BigDecimal verifiedLongitude = null;
        BigDecimal distanceM = null;
        BigDecimal accuracyM = null;
        if (quest.getCompletionType() == CompletionType.LOCATION &&
            checkAccuracy(request, quest)) {
            verifiedLatitude = quest.getLatitude();
            verifiedLongitude = quest.getLongitude();
            accuracyM = request.accuracy();
            distanceM = BigDecimal.valueOf(
                calculateDistance(
                    verifiedLatitude.doubleValue(),
                    verifiedLongitude.doubleValue(),
                    request.latitude().doubleValue(),
                    request.longitude().doubleValue()
                ));

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
                verifiedLatitude,
                verifiedLongitude,
                distanceM,
                accuracyM,
                now
            ));

        GrowthResult growthResult = growthService.grantExp(
            requestUserId, "QUEST_COMPLETION", questCompletion.getId(), quest.getExpReward());

        GrowthSnapshot growthSnapshot = growthService.getGrowthById(requestUserId);

        return new QuestCompletionResponse(
            questCompletion.getId(),
            userDailyQuest.getId(),
            quest.getId(),
            quest.getGrade(),
            now,
            false,
            new QuestCompletionResponse.Location(distanceM, accuracyM),
            new QuestCompletionResponse.Growth(
                growthResult.expGained(),
                growthSnapshot.totalExp(),
                growthResult.previousLevel(),
                growthResult.currentLevel(),
                growthResult.levelUp(),
                growthResult.rewards()),
            QuestCompletionResponse.nothingCollected());
    }

    private double calculateDistance(
        double assignedLat, double assignedLon,  // 배정 위치
        double requestLat, double requestLon     // 요청 위치
    ) {
        final double EARTH_RADIUS_M = 6371000;

        // 라디안으로 변환
        double assignedLatRad = Math.toRadians(assignedLat);
        double assignedLonRad = Math.toRadians(assignedLon);
        double requestLatRad = Math.toRadians(requestLat);
        double requestLonRad = Math.toRadians(requestLon);

        // 위도·경도 차이(라디안)
        double deltaLatRad = requestLatRad - assignedLatRad;
        double deltaLonRad = requestLonRad - assignedLonRad;

        // 삼각함수 중간값 계산
        double sinDeltaLatHalf = Math.sin(deltaLatRad / 2);
        double sinDeltaLonHalf = Math.sin(deltaLonRad / 2);
        double cosAssignedLat = Math.cos(assignedLatRad);
        double cosRequestLat = Math.cos(requestLatRad);

        // Haversine 공식의 a 값
        // a = sin²(Δlat/2) + cos(lat₁)·cos(lat₂)·sin²(Δlon/2)
        double a = sinDeltaLatHalf * sinDeltaLatHalf +
            cosAssignedLat * cosRequestLat *
                sinDeltaLonHalf * sinDeltaLonHalf;

        // 중심각(라디안)
        // c = 2·atan2(√a, √(1-a))
        double centralAngleRad = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

        // 거리(미터)
        return EARTH_RADIUS_M * centralAngleRad;
    }
}
