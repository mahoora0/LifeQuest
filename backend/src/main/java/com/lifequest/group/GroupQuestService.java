package com.lifequest.group;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.growth.GrowthService;
import com.lifequest.group.dto.*;
import com.lifequest.quest.domain.QuestFeature;
import com.lifequest.quest.service.QuestUnlockPolicy;
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GroupQuestService {
    private static final String EXP_SOURCE = "GROUP_QUEST_COMPLETION";

    private final GroupRepository groups;
    private final GroupMemberRepository members;
    private final GroupQuestRepository quests;
    private final GroupQuestParticipantRepository participants;
    private final UserRepository users;
    private final QuestUnlockPolicy unlockPolicy;
    private final GrowthService growthService;
    private final Clock clock;

    public GroupQuestService(
        GroupRepository groups,
        GroupMemberRepository members,
        GroupQuestRepository quests,
        GroupQuestParticipantRepository participants,
        UserRepository users,
        QuestUnlockPolicy unlockPolicy,
        GrowthService growthService,
        Clock clock
    ) {
        this.groups = groups;
        this.members = members;
        this.quests = quests;
        this.participants = participants;
        this.users = users;
        this.unlockPolicy = unlockPolicy;
        this.growthService = growthService;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public PagedResponse<GroupQuestResponse> list(
        Long groupId, Long userId, GroupQuestScope scope, int page, int size
    ) {
        requireMember(groupId, userId);
        unlockPolicy.requireUnlocked(userId, QuestFeature.COOP);
        validatePage(page, size);
        if (scope == null) throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        Page<GroupQuest> result = scope == GroupQuestScope.UPCOMING
            ? quests.findUpcoming(groupId, now(), PageRequest.of(page, size))
            : quests.findPast(groupId, now(), PageRequest.of(page, size));
        return PagedResponse.from(result, quest -> response(quest, userId, false));
    }

    @Transactional(readOnly = true)
    public PagedResponse<GroupQuestResponse> listMine(
        Long userId, GroupQuestScope scope, int page, int size
    ) {
        unlockPolicy.requireUnlocked(userId, QuestFeature.COOP);
        validatePage(page, size);
        if (scope == null) throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        Page<GroupQuest> result = scope == GroupQuestScope.UPCOMING
            ? quests.findMineUpcoming(userId, now(), PageRequest.of(page, size))
            : quests.findMinePast(userId, now(), PageRequest.of(page, size));
        return PagedResponse.from(result, quest -> response(quest, userId, false));
    }

    @Transactional(readOnly = true)
    public GroupQuestResponse detail(Long groupId, Long userId, Long questId) {
        requireMember(groupId, userId);
        unlockPolicy.requireUnlocked(userId, QuestFeature.COOP);
        return response(find(groupId, questId), userId, true);
    }

    @Transactional
    public GroupQuestResponse create(Long groupId, Long userId, CreateGroupQuestRequest request) {
        Group group = owner(groupId, userId);
        unlockPolicy.requireUnlocked(userId, QuestFeature.COOP);
        LocalDateTime now = now();
        validateSchedule(request.scheduledAt(), now);
        GroupQuest saved = quests.save(new GroupQuest(
            group,
            user(userId),
            text(request.title(), 2, 100),
            text(request.description(), 1, 1000),
            text(request.placeName(), 1, 200),
            request.scheduledAt(),
            now));
        return response(saved, userId, true);
    }

    @Transactional
    public GroupQuestResponse update(
        Long groupId, Long userId, Long questId, UpdateGroupQuestRequest request
    ) {
        owner(groupId, userId);
        GroupQuest quest = findForUpdate(groupId, questId);
        LocalDateTime now = now();
        modifiable(quest, now);
        validateSchedule(request.scheduledAt(), now);
        quest.update(
            text(request.title(), 2, 100),
            text(request.description(), 1, 1000),
            text(request.placeName(), 1, 200),
            request.scheduledAt(),
            now);
        return response(quest, userId, true);
    }

    @Transactional
    public GroupQuestResponse cancel(Long groupId, Long userId, Long questId) {
        owner(groupId, userId);
        GroupQuest quest = findForUpdate(groupId, questId);
        LocalDateTime now = now();
        modifiable(quest, now);
        quest.cancel(now);
        return response(quest, userId, true);
    }

    @Transactional
    public GroupQuestResponse apply(Long groupId, Long userId, Long questId) {
        GroupMember member = requireMember(groupId, userId);
        requireActive(member.getGroup());
        unlockPolicy.requireUnlocked(userId, QuestFeature.COOP);
        GroupQuest quest = findForUpdate(groupId, questId);
        LocalDateTime now = now();
        requireParticipationOpen(quest, now);

        GroupQuestParticipant participant = participants
            .findByQuestIdAndUserId(questId, userId)
            .orElse(null);
        if (participant == null) {
            participants.save(new GroupQuestParticipant(quest, member.getUser(), now));
        } else if (participant.getStatus() == GroupQuestParticipationStatus.WITHDRAWN) {
            participant.apply(now);
        }
        return response(quest, userId, true);
    }

    @Transactional
    public GroupQuestResponse withdraw(Long groupId, Long userId, Long questId) {
        GroupMember member = requireMember(groupId, userId);
        requireActive(member.getGroup());
        GroupQuest quest = findForUpdate(groupId, questId);
        LocalDateTime now = now();
        requireParticipationOpen(quest, now);
        GroupQuestParticipant participant = participants
            .findByQuestIdAndUserId(questId, userId)
            .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_QUEST_NOT_PARTICIPATING));
        if (participant.getStatus() == GroupQuestParticipationStatus.APPLIED) {
            participant.withdraw(now);
        } else if (participant.getStatus() == GroupQuestParticipationStatus.REWARDED) {
            throw new BusinessException(ErrorCode.GROUP_QUEST_ALREADY_COMPLETED);
        }
        return response(quest, userId, true);
    }

    @Transactional
    public GroupQuestResponse complete(Long groupId, Long userId, Long questId) {
        owner(groupId, userId);
        unlockPolicy.requireUnlocked(userId, QuestFeature.COOP);
        GroupQuest quest = findForUpdate(groupId, questId);
        if (quest.getStatus() == GroupQuestStatus.COMPLETED) {
            return response(quest, userId, true);
        }
        if (quest.getStatus() == GroupQuestStatus.CANCELLED) {
            throw new BusinessException(ErrorCode.GROUP_QUEST_CANCELLED);
        }

        LocalDateTime now = now();
        if (quest.getScheduledAt().isAfter(now)) {
            throw new BusinessException(ErrorCode.GROUP_QUEST_NOT_STARTED);
        }

        List<GroupQuestParticipant> applied = participants
            .findByQuestIdAndStatusOrderByIdAsc(
                questId, GroupQuestParticipationStatus.APPLIED);
        List<GroupQuestParticipant> eligible = applied.stream()
            .filter(participant -> isActiveMember(groupId, participant.getUser().getId()))
            .sorted(Comparator.comparing(participant -> participant.getUser().getId()))
            .toList();
        applied.stream()
            .filter(participant -> !eligible.contains(participant))
            .forEach(participant -> participant.withdraw(now));
        if (eligible.isEmpty()) {
            throw new BusinessException(ErrorCode.GROUP_QUEST_NO_PARTICIPANTS);
        }

        for (GroupQuestParticipant participant : eligible) {
            growthService.grantExp(
                participant.getUser().getId(), EXP_SOURCE, quest.getId(), quest.getExpReward());
            participant.reward(now);
        }
        quest.complete(now);
        return response(quest, userId, true);
    }

    private GroupQuestResponse response(GroupQuest quest, Long userId, boolean includeParticipants) {
        List<GroupQuestParticipant> all = includeParticipants
            ? participants.findByQuestIdOrderByIdAsc(quest.getId())
            : List.of();
        long participantCount = includeParticipants
            ? all.stream().filter(this::countsAsParticipant).count()
            : participants.countByQuestIdAndStatusIn(
                quest.getId(),
                List.of(GroupQuestParticipationStatus.APPLIED, GroupQuestParticipationStatus.REWARDED));
        GroupQuestParticipationStatus mine = includeParticipants
            ? all.stream()
                .filter(p -> p.getUser().getId().equals(userId))
                .map(GroupQuestParticipant::getStatus)
                .findFirst()
                .orElse(null)
            : participants.findStatus(quest.getId(), userId).orElse(null);
        List<GroupQuestParticipantResponse> participantItems = includeParticipants
            ? all.stream()
                .filter(this::countsAsParticipant)
                .map(GroupQuestParticipantResponse::from)
                .toList()
            : null;
        return new GroupQuestResponse(
            quest.getId(), quest.getGroup().getId(), quest.getGroup().getName(),
            quest.getCreatedBy().getId(), quest.getCreatedBy().getNickname(),
            quest.getTitle(), quest.getDescription(), quest.getPlaceName(),
            quest.getScheduledAt(), quest.getStatus(), quest.getExpReward(),
            participantCount, mine, participantItems, quest.getCompletedAt(),
            quest.getCreatedAt(), quest.getUpdatedAt());
    }

    private boolean countsAsParticipant(GroupQuestParticipant participant) {
        return participant.getStatus() == GroupQuestParticipationStatus.APPLIED
            || participant.getStatus() == GroupQuestParticipationStatus.REWARDED;
    }

    private Group owner(Long groupId, Long userId) {
        Group group = groups.findById(groupId)
            .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_NOT_FOUND));
        requireActive(group);
        if (!group.getOwner().getId().equals(userId)) {
            throw new BusinessException(ErrorCode.GROUP_OWNER_REQUIRED);
        }
        return group;
    }

    private GroupMember requireMember(Long groupId, Long userId) {
        return members.findByGroupIdAndUserId(groupId, userId)
            .filter(member -> member.getStatus() == GroupMemberStatus.ACTIVE)
            .orElseThrow(() -> new BusinessException(ErrorCode.GROUP_ACCESS_DENIED));
    }

    private boolean isActiveMember(Long groupId, Long userId) {
        return members.findByGroupIdAndUserId(groupId, userId)
            .filter(member -> member.getStatus() == GroupMemberStatus.ACTIVE)
            .isPresent();
    }

    private GroupQuest find(Long groupId, Long questId) {
        return quests.findByIdAndGroupId(questId, groupId)
            .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
    }

    private GroupQuest findForUpdate(Long groupId, Long questId) {
        return quests.findByIdAndGroupIdForUpdate(questId, groupId)
            .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
    }

    private void modifiable(GroupQuest quest, LocalDateTime now) {
        if (quest.getStatus() == GroupQuestStatus.CANCELLED) {
            throw new BusinessException(ErrorCode.GROUP_QUEST_CANCELLED);
        }
        if (quest.getStatus() == GroupQuestStatus.COMPLETED) {
            throw new BusinessException(ErrorCode.GROUP_QUEST_ALREADY_COMPLETED);
        }
        if (!quest.getScheduledAt().isAfter(now)) {
            throw new BusinessException(ErrorCode.GROUP_QUEST_ALREADY_STARTED);
        }
    }

    private void requireParticipationOpen(GroupQuest quest, LocalDateTime now) {
        if (quest.getStatus() != GroupQuestStatus.PUBLISHED
            || !quest.getScheduledAt().isAfter(now)) {
            throw new BusinessException(ErrorCode.GROUP_QUEST_PARTICIPATION_CLOSED);
        }
    }

    private void requireActive(Group group) {
        if (group.getStatus() != GroupStatus.ACTIVE) {
            throw new BusinessException(ErrorCode.GROUP_ARCHIVED);
        }
    }

    private User user(Long userId) {
        return users.findById(userId)
            .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
    }

    private void validateSchedule(LocalDateTime value, LocalDateTime now) {
        if (value == null || !value.isAfter(now)) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
    }

    private String text(String value, int min, int max) {
        String result = value == null ? "" : value.trim();
        if (result.length() < min || result.length() > max) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        return result;
    }

    private LocalDateTime now() { return LocalDateTime.now(clock); }

    private void validatePage(int page, int size) {
        if (page < 0 || size < 1 || size > 50) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
    }
}
