package com.lifequest.profile;

import com.lifequest.collection.LifedexService;
import com.lifequest.growth.RewardGrant;
import com.lifequest.quest.repository.QuestCompletionRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.function.Predicate;
import org.springframework.stereotype.Service;

/** 퀘스트 완료 직후 누적 기록을 평가해 조건을 만족한 칭호를 한 번만 지급한다. */
@Service
public class TitleAwardService {

    private static final List<Rule> RULES = List.of(
            quest("QUEST_FIRST_STEP", p -> p.questCount() >= 1),
            quest("QUEST_DAILY_10", p -> p.questCount() >= 10),
            quest("QUEST_30", p -> p.questCount() >= 30),
            quest("QUEST_100", p -> p.questCount() >= 100),
            quest("QUEST_LOCATION_5", p -> p.locationCount() >= 5),
            quest("QUEST_LOCATION_15", p -> p.locationCount() >= 15),
            quest("QUEST_SELF_REPORT_10", p -> p.selfReportCount() >= 10),
            quest("QUEST_WEEKLY_5", p -> p.weeklyCount() >= 5),
            quest("QUEST_LEGENDARY_1", p -> p.legendaryCount() >= 1),
            lifedex("LIFEDEX_FIRST_PAGE", p -> p.lifedexCount() >= 1),
            lifedex("LIFEDEX_5", p -> p.lifedexCount() >= 5),
            lifedex("LIFEDEX_10", p -> p.lifedexCount() >= 10),
            lifedex("LIFEDEX_COMPLETE", Progress::lifedexComplete),
            category("LIFEDEX_CAFE_COMPLETE", 1L),
            category("LIFEDEX_PARK_COMPLETE", 2L),
            category("LIFEDEX_CULTURE_COMPLETE", 3L),
            category("LIFEDEX_MARKET_COMPLETE", 4L),
            category("LIFEDEX_NATURE_COMPLETE", 5L),
            category("LIFEDEX_HISTORY_COMPLETE", 6L));

    private final QuestCompletionRepository questCompletionRepository;
    private final LifedexService lifedexService;
    private final TitleRepository titleRepository;
    private final UserTitleRepository userTitleRepository;

    public TitleAwardService(
            QuestCompletionRepository questCompletionRepository,
            LifedexService lifedexService,
            TitleRepository titleRepository,
            UserTitleRepository userTitleRepository) {
        this.questCompletionRepository = questCompletionRepository;
        this.lifedexService = lifedexService;
        this.titleRepository = titleRepository;
        this.userTitleRepository = userTitleRepository;
    }

    public List<RewardGrant> grantEligibleTitles(Long userId, Long questCompletionId) {
        Progress progress = progress(userId);
        List<RewardGrant> grants = new ArrayList<>();
        for (Rule rule : RULES) {
            if (!rule.condition().test(progress)) {
                continue;
            }
            int inserted = userTitleRepository.insertIfAbsent(
                    userId, rule.code(), rule.sourceType(), questCompletionId);
            if (inserted == 0) {
                continue;
            }
            Title title = titleRepository.findByCode(rule.code())
                    .orElseThrow(() -> new IllegalStateException(
                            "칭호 카탈로그가 누락되었습니다: " + rule.code()));
            grants.add(new RewardGrant("TITLE", title.getCode(), title.getName()));
        }
        return List.copyOf(grants);
    }

    private Progress progress(Long userId) {
        LifedexService.LifedexProgress lifedex = lifedexService.progress(userId);
        return new Progress(
                questCompletionRepository.countByUserId(userId),
                questCompletionRepository.countByUserIdAndCompletionType(userId, "LOCATION"),
                questCompletionRepository.countByUserIdAndCompletionType(userId, "SELF_REPORT"),
                questCompletionRepository.countByUserIdAndCadence(userId, "WEEKLY"),
                questCompletionRepository.countByUserIdAndGrade(userId, "LEGENDARY"),
                lifedex.collectedCount(),
                lifedex.totalCount(),
                lifedex.completedCategoryIds());
    }

    private static Rule quest(String code, Predicate<Progress> condition) {
        return new Rule(code, "QUEST", condition);
    }

    private static Rule lifedex(String code, Predicate<Progress> condition) {
        return new Rule(code, "LIFEDEX", condition);
    }

    private static Rule category(String code, Long categoryId) {
        return lifedex(code, progress -> progress.completedCategoryIds().contains(categoryId));
    }

    private record Rule(String code, String sourceType, Predicate<Progress> condition) {
    }

    private record Progress(
            long questCount,
            long locationCount,
            long selfReportCount,
            long weeklyCount,
            long legendaryCount,
            long lifedexCount,
            long lifedexTotalCount,
            Set<Long> completedCategoryIds) {

        boolean lifedexComplete() {
            return lifedexTotalCount > 0 && lifedexCount >= lifedexTotalCount;
        }
    }
}
