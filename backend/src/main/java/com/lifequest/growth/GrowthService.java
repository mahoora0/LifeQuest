package com.lifequest.growth;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class GrowthService {

    private final UserRepository userRepository;
    private final ExpLogRepository expLogRepository;
    private final RewardService rewardService;

    public GrowthService(
        UserRepository userRepository,
        ExpLogRepository expLogRepository,
        RewardService rewardService) {
        this.userRepository = userRepository;
        this.expLogRepository = expLogRepository;
        this.rewardService = rewardService;
    }

    @Transactional
    public GrowthResult grantExp(
        Long userId, String sourceType, Long sourceId, int expAmount) {
        if (expAmount <= 0) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }

        User user = userRepository.findByIdForUpdate(userId)
            .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
        int previousLevel = user.getLevel();
        if (expLogRepository.existsByUserIdAndSourceTypeAndSourceId(
            userId, sourceType, sourceId)) {
            return new GrowthResult(
                0, previousLevel, previousLevel, false, true, List.of());
        }

        int totalExp = user.getTotalExp() + expAmount;
        int currentLevel = levelFor(totalExp);
        expLogRepository.save(new ExpLog(user, sourceType, sourceId, expAmount));
        user.addExp(expAmount, currentLevel);

        List<RewardGrant> rewards = currentLevel > previousLevel
            ? rewardService.grantLevelRewards(user, previousLevel + 1, currentLevel)
            : List.of();
        return new GrowthResult(
            expAmount,
            previousLevel,
            currentLevel,
            currentLevel > previousLevel,
            false,
            rewards);
    }

    public GrowthSnapshot getGrowthById(Long userId) {
        User user = userRepository.findByIdForUpdate(userId)
            .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
        return new GrowthSnapshot(user.getTotalExp(), user.getLevel());
    }

    public static int levelFor(int totalExp) {
        int level = 1;
        while (totalExp >= cumulativeExpForLevel(level + 1)) {
            level++;
        }
        return level;
    }

    public static int cumulativeExpForLevel(int level) {
        return 100 * (level - 1) * level / 2;
    }

    public static int requiredExpForNextLevel(int level) {
        return 100 * level;
    }
}
