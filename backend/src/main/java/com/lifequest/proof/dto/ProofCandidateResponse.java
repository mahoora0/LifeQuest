package com.lifequest.proof.dto;

import com.lifequest.quest.domain.QuestGrade;
import java.time.LocalDateTime;

/**
 * 아직 인증 게시물을 올리지 않은 내 퀘스트 완료 기록. 작성 화면이 "어떤 퀘스트를 인증할지"
 * 목록을 여기서 받는다.
 *
 * <p>퀘스트를 사용자가 직접 입력하지 않고 이 목록에서 고르게 하는 것이 요점이다 — 하지 않은
 * 퀘스트를 인증 대상으로 올릴 수 있는 경로가 애초에 생기지 않는다.
 */
public record ProofCandidateResponse(
        Long completionId,
        Long questId,
        String questTitle,
        QuestGrade questGrade,
        LocalDateTime completedAt) {
}
