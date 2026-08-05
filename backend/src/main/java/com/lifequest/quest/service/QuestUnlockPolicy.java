package com.lifequest.quest.service;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.quest.domain.QuestFeature;
import com.lifequest.user.UserRepository;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class QuestUnlockPolicy {

    public static final int DAILY_REQUIRED_LEVEL = 1;
    public static final int WEEKLY_REQUIRED_LEVEL = 3;
    public static final int COOP_REQUIRED_LEVEL = 5;

    private final UserRepository userRepository;

    public QuestUnlockPolicy(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public boolean isUnlocked(int level, QuestFeature feature) {
        return level >= requiredLevel(feature);
    }

    public int requiredLevel(QuestFeature feature) {
        return switch (feature) {
            case DAILY -> DAILY_REQUIRED_LEVEL;
            case WEEKLY -> WEEKLY_REQUIRED_LEVEL;
            case COOP -> COOP_REQUIRED_LEVEL;
        };
    }

    @Transactional(readOnly = true)
    public void requireUnlocked(Long userId, QuestFeature feature) {
        int level = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND))
                .getLevel();
        if (!isUnlocked(level, feature)) {
            throw new BusinessException(
                    ErrorCode.QUEST_FEATURE_LOCKED,
                    "Lv. " + requiredLevel(feature) + "에 열리는 기능입니다.");
        }
    }
}
