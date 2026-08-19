package com.lifequest.admin;

import com.lifequest.admin.dto.AdminDashboardResponse;
import com.lifequest.growth.ExpLogRepository;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.repository.QuestCompletionRepository;
import com.lifequest.quest.repository.QuestRepository;
import com.lifequest.user.UserRepository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminDashboardService {
        private final UserRepository users;
        private final QuestRepository quests;
        private final QuestCompletionRepository completions;
        private final ExpLogRepository expLogs;

        public AdminDashboardService(UserRepository users, QuestRepository quests,
                        QuestCompletionRepository completions, ExpLogRepository expLogs) {
                this.users = users;
                this.quests = quests;
                this.completions = completions;
                this.expLogs = expLogs;
        }

        @Transactional(readOnly = true)
        public AdminDashboardResponse getDashboard() {
                Map<Long, Quest> questMap = quests.findAll().stream()
                                .collect(Collectors.toMap(Quest::getId, Function.identity()));
                var recentUsers = users.findAllByOrderByCreatedAtDesc(PageRequest.of(0, 5)).stream()
                                .map(user -> new AdminDashboardResponse.RecentUser(
                                                user.getId(), user.getNickname(), user.getEmail(), user.getLevel(),
                                                user.getCreatedAt()))
                                .toList();
                var recentCompletions = completions.findTop10ByOrderByCompletedAtDescIdDesc().stream()
                                .map(completion -> {
                                        Quest quest = questMap.get(completion.getQuestId());
                                        var user = users.findById(completion.getUserId()).orElse(null);
                                        return new AdminDashboardResponse.RecentCompletion(
                                                        completion.getUserId(),
                                                        user == null ? "탈퇴 사용자" : user.getNickname(),
                                                        completion.getQuestId(),
                                                        quest == null ? "삭제된 퀘스트" : quest.getTitle(),
                                                        quest == null ? 0 : quest.getExpReward(),
                                                        completion.getCompletedAt());
                                }).toList();
                var recentExp = expLogs.findTop10ByOrderByCreatedAtDescIdDesc().stream()
                                .map(log -> new AdminDashboardResponse.RecentExp(
                                                log.getUser().getId(), log.getUser().getNickname(), log.getSourceType(),
                                                log.getExpAmount(), log.getCreatedAt()))
                                .toList();
                var popular = completions.findPopularQuestCounts(PageRequest.of(0, 5)).stream()
                                .map(row -> {
                                        Long questId = (Long) row[0];
                                        Quest quest = questMap.get(questId);
                                        return new AdminDashboardResponse.PopularQuest(
                                                        questId, quest == null ? "삭제된 퀘스트" : quest.getTitle(),
                                                        (Long) row[1]);
                                }).toList();
                return new AdminDashboardResponse(
                                users.count(), quests.countByActiveTrue(), quests.count(), completions.count(),
                                completions.countByCompletedAtGreaterThanEqual(LocalDate.now().atStartOfDay()),
                                expLogs.sumExpAmount(), quests.countByCadence(QuestCadence.DAILY),
                                quests.countByCadence(QuestCadence.WEEKLY), recentUsers, recentCompletions,
                                recentExp, popular);
        }
}
