package com.lifequest.quest.service;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.quest.dto.QuestHistoryPageResponse;
import com.lifequest.quest.repository.QuestCompletionRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class QuestHistoryService {

    private final QuestCompletionRepository questCompletionRepository;

    public QuestHistoryService(QuestCompletionRepository questCompletionRepository) {
        this.questCompletionRepository = questCompletionRepository;
    }

    @Transactional(readOnly = true)
    public QuestHistoryPageResponse history(Long userId, int page, int size) {
        if (page < 0 || size < 1 || size > 100) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        return QuestHistoryPageResponse.from(
                questCompletionRepository.findHistoryByUserId(
                        userId, PageRequest.of(page, size)));
    }
}
