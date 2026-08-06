package com.lifequest.quest.service;

import com.lifequest.quest.domain.QuestAssignmentMarker;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.repository.QuestAssignmentMarkerRepository;
import jakarta.validation.constraints.NotNull;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.validation.annotation.Validated;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Service
@Transactional
@Validated
public class QuestAssignmentCreator {
//    createForTrack(userId, track, today):     # REQUIRES_NEW + READ_COMMITTED
//        periodStart = track별 주기 시작일(today)
//    expiresAt   = track별 만료 시각(periodStart)
//
//    try:
//        markerRepo.saveAndFlush(마커(userId, track, periodStart))
//        catch DataIntegrityViolationException:
//        return          # 경합에서 짐. 이 트랜잭션은 롤백되고 바깥이 재조회한다
//
//        pool = 활성 퀘스트 중 cadence == track
//        prev = 직전 주기에 이 사용자에게 배정된 questId 집합
//    for quest in drawer.draw(pool, prev):
//        udqRepo.save(배정(userId, quest.id, periodStart, expiresAt))
    QuestAssignmentMarkerRepository questAssignmentMarkerRepository;
    Clock clock;

    public QuestAssignmentCreator(QuestAssignmentMarkerRepository questAssignmentMarkerRepository, Clock clock) {
        this.questAssignmentMarkerRepository = questAssignmentMarkerRepository;
        this.clock = clock;
    }

    public void createForTrack(@NotNull Long userId, @NotNull QuestCadence questCadence, LocalDate periodStart) {

        try {
            questAssignmentMarkerRepository.saveAndFlush(new QuestAssignmentMarker(userId, questCadence, periodStart, LocalDateTime.now(clock)));
        } catch (DataIntegrityViolationException e) {
            return;
        }


    }
}
