package com.lifequest.admin;

import com.lifequest.admin.dto.AdminUserDetailResponse;
import com.lifequest.admin.dto.AdminUserPageResponse;
import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.growth.ExpLogRepository;
import com.lifequest.quest.domain.DailyQuestStatus;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.repository.QuestCompletionRepository;
import com.lifequest.quest.repository.QuestRepository;
import com.lifequest.quest.repository.UserDailyQuestRepository;
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminUserService {
    private final UserRepository users;
    private final QuestRepository quests;
    private final UserDailyQuestRepository assignments;
    private final QuestCompletionRepository completions;
    private final ExpLogRepository expLogs;

    public AdminUserService(UserRepository users, QuestRepository quests,
                            UserDailyQuestRepository assignments,
                            QuestCompletionRepository completions, ExpLogRepository expLogs) {
        this.users = users;
        this.quests = quests;
        this.assignments = assignments;
        this.completions = completions;
        this.expLogs = expLogs;
    }

    @Transactional(readOnly = true)
    public AdminUserPageResponse getUsers(String query, int page, int size) {
        PageRequest pageable = PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), 100),
                Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<User> result = query == null || query.isBlank()
                ? users.findAll(pageable)
                : users.searchForAdmin(query.trim(), pageable);
        double average = users.findAll().stream().mapToInt(User::getLevel).average().orElse(0);
        Instant today = LocalDate.now(ZoneId.of("Asia/Seoul")).atStartOfDay(ZoneId.of("Asia/Seoul")).toInstant();
        return new AdminUserPageResponse(result.stream().map(AdminUserPageResponse.UserRow::from).toList(),
                result.getNumber(), result.getSize(), result.getTotalElements(), result.getTotalPages(),
                new AdminUserPageResponse.UserStats(users.count(), users.countByCreatedAtGreaterThanEqual(today), average));
    }

    @Transactional(readOnly = true)
    public AdminUserDetailResponse getUser(Long userId) {
        User user = users.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
        Map<Long, Quest> questMap = quests.findAll().stream()
                .collect(Collectors.toMap(Quest::getId, Function.identity()));
        var recentQuests = assignments.findTop10ByUserIdOrderByAssignedDateDescIdDesc(userId).stream()
                .map(assignment -> {
                    Quest quest = questMap.get(assignment.getQuestId());
                    var completion = completions.findByUserDailyQuestId(assignment.getId()).orElse(null);
                    return new AdminUserDetailResponse.QuestActivity(
                            assignment.getId(), assignment.getQuestId(),
                            quest == null ? "삭제된 퀘스트" : quest.getTitle(),
                            quest == null ? null : quest.getCadence(), quest == null ? 0 : quest.getExpReward(),
                            assignment.getStatus(), assignment.getAssignedDate(),
                            completion == null ? null : completion.getCompletedAt());
                }).toList();
        var recentExp = expLogs.findTop10ByUserIdOrderByCreatedAtDescIdDesc(userId).stream()
                .map(log -> new AdminUserDetailResponse.ExpActivity(
                        log.getId(), log.getSourceType(), log.getSourceId(),
                        expDescription(log.getSourceType(), log.getSourceId(), questMap),
                        log.getExpAmount(), log.getCreatedAt())).toList();
        return new AdminUserDetailResponse(
                user.getId(), user.getNickname(), user.getEmail(), user.getProfileImageUrl(), user.getRole(),
                user.getLevel(), user.getTotalExp(),
                user.getRepresentativeTitle() == null ? null : user.getRepresentativeTitle().getName(),
                user.getRepresentativeBadge() == null ? null : user.getRepresentativeBadge().getName(),
                user.getCreatedAt(), completions.countByUserId(userId),
                assignments.countByUserIdAndStatus(userId, DailyQuestStatus.ASSIGNED), recentQuests, recentExp);
    }

    private String expDescription(String sourceType, Long sourceId, Map<Long, Quest> quests) {
        if ("QUEST".equals(sourceType) || "QUEST_COMPLETION".equals(sourceType)) {
            Quest quest = quests.get(sourceId);
            return quest == null ? "퀘스트 완료" : quest.getTitle();
        }
        return sourceType;
    }
}
