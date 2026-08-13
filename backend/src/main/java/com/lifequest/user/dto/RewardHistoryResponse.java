package com.lifequest.user.dto;

import java.time.Instant;
import java.util.List;

/** 레벨 진행도와 보상 화면(S-05)에 필요한 데이터를 한 번에 내려준다. */
public record RewardHistoryResponse(
        int level,
        int exp,
        int expForNextLevel,
        Integer questsToNextLevel,
        NextMilestone nextMilestone,
        List<ReceivedReward> received,
        List<DailyExp> weeklyExp,
        // 기존 프로필 화면 계약을 유지한다.
        List<TitleResponse> titles,
        List<ProfileItemResponse> profileItems) {

    public record NextMilestone(int level, String rewardLine) {
    }

    public record ReceivedReward(
            int level,
            String name,
            String kind,
            Instant acquiredAt,
            String timeLabel,
            String note) {
    }

    public record DailyExp(String dayLabel, int exp) {
    }
}
