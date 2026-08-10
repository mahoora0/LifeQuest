package com.lifequest.collection;

import com.lifequest.growth.RewardGrant;
import com.lifequest.profile.Title;
import com.lifequest.profile.TitleRepository;
import com.lifequest.profile.UserTitleRepository;
import com.lifequest.quest.repository.QuestCompletionRepository;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.LongSupplier;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AchievementService {

    private final AchievementRepository achievementRepository;
    private final AchievementStepRepository stepRepository;
    private final UserAchievementRepository userAchievementRepository;
    private final QuestCompletionRepository questCompletionRepository;
    private final UserLifedexRepository userLifedexRepository;
    private final UserTitleRepository userTitleRepository;
    private final TitleRepository titleRepository;

    AchievementService(
            AchievementRepository achievementRepository,
            AchievementStepRepository stepRepository,
            UserAchievementRepository userAchievementRepository,
            QuestCompletionRepository questCompletionRepository,
            UserLifedexRepository userLifedexRepository,
            UserTitleRepository userTitleRepository,
            TitleRepository titleRepository) {
        this.achievementRepository = achievementRepository;
        this.stepRepository = stepRepository;
        this.userAchievementRepository = userAchievementRepository;
        this.questCompletionRepository = questCompletionRepository;
        this.userLifedexRepository = userLifedexRepository;
        this.userTitleRepository = userTitleRepository;
        this.titleRepository = titleRepository;
    }

    @Transactional(readOnly = true)
    public AchievementResponse catalog(Long userId) {
        Map<Long, Integer> reachedSteps = reachedSteps(userId);
        Map<Long, List<AchievementStep>> stepsByAchievement = stepsByAchievement();
        List<AchievementResponse.Item> items = new ArrayList<>();
        for (Achievement achievement : achievementRepository.findAllByOrderByDisplayOrderAsc()) {
            List<AchievementStep> steps = stepsByAchievement.getOrDefault(
                    achievement.getId(), List.of());
            boolean revealed = reachedSteps.getOrDefault(achievement.getId(), 0) > 0;
            boolean hidden = achievement.isSecret() && !revealed;
            items.add(toResponse(achievement, steps, 0, 0, hidden));
        }
        return new AchievementResponse(List.copyOf(items));
    }

    @Transactional(readOnly = true)
    public AchievementResponse mine(Long userId) {
        Map<Long, List<AchievementStep>> stepsByAchievement = stepsByAchievement();
        Map<String, Long> countCache = new HashMap<>();
        List<AchievementResponse.Item> items = new ArrayList<>();
        for (Achievement achievement : achievementRepository.findAllByOrderByDisplayOrderAsc()) {
            List<AchievementStep> steps = stepsByAchievement.getOrDefault(
                    achievement.getId(), List.of());
            int currentValue = Math.toIntExact(count(userId, achievement, countCache));
            int currentStep = reachedStep(steps, currentValue);
            boolean hidden = achievement.isSecret() && currentStep == 0;
            items.add(toResponse(
                    achievement, steps, currentValue, currentStep, hidden));
        }
        return new AchievementResponse(List.copyOf(items));
    }

    @Transactional
    public List<CollectionOutcome.Entry> evaluate(Long userId) {
        Map<Long, List<AchievementStep>> stepsByAchievement = stepsByAchievement();
        Map<Long, UserAchievement> progressByAchievement = new HashMap<>();
        for (UserAchievement progress : userAchievementRepository.findByUserId(userId)) {
            progressByAchievement.put(progress.getAchievementId(), progress);
        }

        Map<String, Long> countCache = new HashMap<>();
        List<CollectionOutcome.Entry> unlocked = new ArrayList<>();
        LocalDateTime now = LocalDateTime.now();
        for (Achievement achievement : achievementRepository.findAllByOrderByDisplayOrderAsc()) {
            List<AchievementStep> steps = stepsByAchievement.getOrDefault(
                    achievement.getId(), List.of());
            if (steps.isEmpty()) {
                continue;
            }

            int currentValue = Math.toIntExact(count(userId, achievement, countCache));
            int reachedStep = reachedStep(steps, currentValue);
            UserAchievement progress = progressByAchievement.get(achievement.getId());
            int previousStep = progress == null ? 0 : progress.getCurrentStep();

            if (progress == null && currentValue > 0) {
                progress = new UserAchievement(userId, achievement.getId());
            }
            if (progress != null) {
                progress.update(currentValue, reachedStep, reachedStep == steps.size(), now);
                userAchievementRepository.save(progress);
            }

            for (AchievementStep step : steps) {
                if (step.getStepNo() <= previousStep || step.getStepNo() > reachedStep) {
                    continue;
                }
                unlocked.add(new CollectionOutcome.Entry(
                        step.getId(),
                        step.getName(),
                        achievement.isSecret(),
                        grantReward(userId, step)));
            }
        }
        return List.copyOf(unlocked);
    }

    private RewardGrant grantReward(Long userId, AchievementStep step) {
        if (step.getRewardTitleId() == null) {
            return null;
        }
        int inserted = userTitleRepository.insertAchievementRewardIfAbsent(
                userId, step.getRewardTitleId(), step.getId());
        if (inserted == 0) {
            return null;
        }
        Title title = titleRepository.findById(step.getRewardTitleId())
                .orElseThrow(() -> new IllegalStateException(
                        "Achievement reward title is missing: " + step.getRewardTitleId()));
        return new RewardGrant("TITLE", title.getCode(), title.getName());
    }

    private AchievementResponse.Item toResponse(
            Achievement achievement,
            List<AchievementStep> steps,
            int currentValue,
            int currentStep,
            boolean hidden) {
        int finalStep = steps.size();
        int requiredValue = steps.isEmpty()
                ? 0
                : steps.get(Math.min(currentStep, finalStep - 1)).getRequiredCount();
        return new AchievementResponse.Item(
                achievement.getId(),
                hidden ? "" : achievement.getName(),
                finalStep > 0 && currentStep >= finalStep,
                achievement.isSecret(),
                hidden ? null : achievement.getDescription(),
                currentValue,
                requiredValue,
                currentStep);
    }

    private Map<Long, Integer> reachedSteps(Long userId) {
        Map<Long, Integer> result = new HashMap<>();
        for (UserAchievement progress : userAchievementRepository.findByUserId(userId)) {
            result.put(progress.getAchievementId(), progress.getCurrentStep());
        }
        return result;
    }

    private Map<Long, List<AchievementStep>> stepsByAchievement() {
        Map<Long, List<AchievementStep>> grouped = new LinkedHashMap<>();
        for (AchievementStep step : stepRepository.findAllByOrderByAchievementIdAscStepNoAsc()) {
            grouped.computeIfAbsent(step.getAchievementId(), ignored -> new ArrayList<>())
                    .add(step);
        }
        return grouped;
    }

    private static int reachedStep(List<AchievementStep> steps, int currentValue) {
        int result = 0;
        for (AchievementStep step : steps) {
            if (currentValue < step.getRequiredCount()) {
                break;
            }
            result = step.getStepNo();
        }
        return result;
    }

    private long count(Long userId, Achievement achievement, Map<String, Long> cache) {
        String type = achievement.getConditionType();
        String key = achievement.getConditionKey();
        return switch (type) {
            case "CUMULATIVE_COUNT" -> cached(cache, type,
                    () -> questCompletionRepository.countByUserId(userId));
            case "COMPLETION_TYPE" -> cached(cache, type + ':' + key,
                    () -> questCompletionRepository.countByUserIdAndCompletionType(userId, key));
            case "CADENCE" -> cached(cache, type + ':' + key,
                    () -> questCompletionRepository.countByUserIdAndCadence(userId, key));
            case "GRADE" -> cached(cache, type + ':' + key,
                    () -> questCompletionRepository.countByUserIdAndGrade(userId, key));
            case "SPECIFIC_QUEST" -> cached(cache, type + ':' + achievement.getTargetQuestId(),
                    () -> questCompletionRepository.countByUserIdAndQuestId(
                            userId, achievement.getTargetQuestId()));
            case "LIFEDEX_COUNT" -> achievement.getTargetLifedexCategoryId() == null
                    ? cached(cache, type,
                            () -> userLifedexRepository.countByUserId(userId))
                    : cached(cache, type + ':' + achievement.getTargetLifedexCategoryId(),
                            () -> userLifedexRepository.countByUserIdAndCategoryId(
                                    userId, achievement.getTargetLifedexCategoryId()));
            default -> throw new IllegalStateException(
                    "Unsupported achievement condition: " + type);
        };
    }

    private static long cached(
            Map<String, Long> cache, String key, LongSupplier supplier) {
        return cache.computeIfAbsent(key, ignored -> supplier.getAsLong());
    }
}
