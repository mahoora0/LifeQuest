package com.lifequest.admin;

import com.lifequest.admin.dto.AdminQuestPageResponse;
import com.lifequest.admin.dto.AdminQuestRequest;
import com.lifequest.admin.dto.AdminQuestResponse;
import com.lifequest.admin.dto.DeactivateQuestResponse;
import com.lifequest.admin.dto.UpdateAdminQuestRequest;
import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.quest.domain.CompletionType;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.domain.QuestCreator;
import com.lifequest.quest.domain.QuestGrade;
import com.lifequest.quest.repository.QuestRepository;
import java.math.BigDecimal;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminQuestService {
    private static final Sort NEWEST_FIRST = Sort.by(
            Sort.Order.desc("createdAt"), Sort.Order.desc("id"));

    private final QuestRepository questRepository;

    public AdminQuestService(QuestRepository questRepository) {
        this.questRepository = questRepository;
    }

    @Transactional(readOnly = true)
    public AdminQuestPageResponse getQuests(int page, int size) {
        validatePage(page, size);
        return AdminQuestPageResponse.from(
                questRepository.findByOwnerUserIdIsNull(PageRequest.of(page, size, NEWEST_FIRST)));
    }

    @Transactional
    public AdminQuestResponse create(AdminQuestRequest request) {
        boolean active = request.active() == null || request.active();
        QuestValues values = normalize(
                request.title(), request.description(), request.grade(), request.cadence(),
                request.completionType(), request.expReward(), request.placeName(),
                request.latitude(), request.longitude(), request.radiusM(),
                request.lifedexItemId(), active);
        Quest quest = new Quest(
                values.title, values.description, values.grade, values.cadence,
                values.completionType, values.expReward, values.placeName,
                values.latitude, values.longitude, values.radiusM, values.lifedexItemId,
                QuestCreator.ADMIN, values.active);
        return AdminQuestResponse.from(questRepository.save(quest));
    }

    @Transactional
    public AdminQuestResponse update(Long questId, UpdateAdminQuestRequest request) {
        Quest quest = getQuest(questId);
        QuestValues values = normalize(
                request.title() == null ? quest.getTitle() : request.title(),
                request.description() == null ? quest.getDescription() : request.description(),
                request.grade() == null ? quest.getGrade() : request.grade(),
                request.cadence() == null ? quest.getCadence() : request.cadence(),
                request.completionType() == null
                        ? quest.getCompletionType() : request.completionType(),
                request.expReward() == null ? quest.getExpReward() : request.expReward(),
                request.placeName() == null ? quest.getPlaceName() : request.placeName(),
                request.latitude() == null ? quest.getLatitude() : request.latitude(),
                request.longitude() == null ? quest.getLongitude() : request.longitude(),
                request.radiusM() == null ? quest.getRadiusM() : request.radiusM(),
                request.lifedexItemId() == null ? quest.getLifedexItemId() : request.lifedexItemId(),
                request.active() == null ? quest.isActive() : request.active());
        quest.update(
                values.title, values.description, values.grade, values.cadence,
                values.completionType, values.expReward, values.placeName,
                values.latitude, values.longitude, values.radiusM,
                values.lifedexItemId, values.active);
        return AdminQuestResponse.from(quest);
    }

    @Transactional
    public DeactivateQuestResponse deactivate(Long questId) {
        Quest quest = getQuest(questId);
        quest.deactivate();
        return DeactivateQuestResponse.success(questId);
    }

    /**
     * 어드민이 다룰 수 있는 것은 공용 카탈로그뿐이다. 개인 AI 퀘스트는 목록에서 빼는 것만으로는
     * 부족하다 — 수정·비활성화는 id만 알면 되는 경로라 어드민이 특정 사용자의 개인 퀘스트를
     * 바꾸거나 내려버릴 수 있다.
     */
    private Quest getQuest(Long questId) {
        return questRepository.findByIdAndOwnerUserIdIsNull(questId)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
    }

    private QuestValues normalize(
            String title, String description, QuestGrade grade, QuestCadence cadence,
            CompletionType completionType, int expReward, String placeName,
            BigDecimal latitude, BigDecimal longitude, Integer radiusM,
            Long lifedexItemId, boolean active) {
        if (title == null || title.isBlank() || grade == null || cadence == null
                || completionType == null || !validExp(grade, expReward)) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        if (completionType == CompletionType.SELF_REPORT) {
            return new QuestValues(title.trim(), description, grade, cadence, completionType,
                    expReward, null, null, null, null, lifedexItemId, active);
        }
        if (placeName == null || placeName.isBlank() || latitude == null || longitude == null
                || radiusM == null || radiusM <= 0
                || latitude.compareTo(BigDecimal.valueOf(-90)) < 0
                || latitude.compareTo(BigDecimal.valueOf(90)) > 0
                || longitude.compareTo(BigDecimal.valueOf(-180)) < 0
                || longitude.compareTo(BigDecimal.valueOf(180)) > 0) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        return new QuestValues(title.trim(), description, grade, cadence, completionType,
                expReward, placeName.trim(), latitude, longitude, radiusM, lifedexItemId, active);
    }

    private boolean validExp(QuestGrade grade, int exp) {
        return switch (grade) {
            case NORMAL -> exp >= 10 && exp <= 20;
            case RARE -> exp >= 30 && exp <= 50;
            case EPIC -> exp >= 60 && exp <= 100;
            case LEGENDARY -> exp >= 150 && exp <= 300;
        };
    }

    private void validatePage(int page, int size) {
        if (page < 0 || size < 1 || size > 100) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
    }

    private record QuestValues(
            String title, String description, QuestGrade grade, QuestCadence cadence,
            CompletionType completionType, int expReward, String placeName,
            BigDecimal latitude, BigDecimal longitude, Integer radiusM,
            Long lifedexItemId, boolean active) {
    }
}
