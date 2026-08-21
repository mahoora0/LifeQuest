package com.lifequest.proof.dto;

import com.lifequest.proof.ProofPostStatus;
import com.lifequest.proof.ProofVoteChoice;
import com.lifequest.quest.domain.QuestGrade;
import com.lifequest.quest.domain.QuestCategory;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 피드 카드와 상세 화면이 같은 모양을 쓴다. 카드에서 바로 투표할 수 있어야 하므로
 * 카드가 상세보다 적은 정보로 그려질 수 없다 — 두 응답을 나누면 카드 쪽이 부족해져서
 * 결국 상세를 한 번 더 부르게 된다.
 *
 * @param decidedVoteCount UNSURE를 뺀 유효 표 수. 화면의 "투표 중 2/3"에서 앞 숫자다
 * @param minVotes         판정에 필요한 표 수. 설정값이라 앱에 하드코딩하지 않고 함께 내린다
 * @param myVote           내가 던진 표. 아직 투표하지 않았으면 {@code null}
 * @param mine             내 게시물인지. 투표 버튼 대신 결과만 보여줄지 정하는 근거다
 * @param questGrade       퀘스트 등급. 카드의 퀘스트명 배지 색을 등급에 맞춘다
 */
public record ProofPostResponse(
        Long postId,
        ProofAuthor author,
        Long questId,
        String questTitle,
        QuestGrade questGrade,
        QuestCategory questCategory,
        String content,
        List<String> photoUrls,
        ProofPostStatus status,
        int agreeCount,
        int unsureCount,
        int rejectCount,
        int decidedVoteCount,
        int minVotes,
        int commentCount,
        ProofVoteChoice myVote,
        boolean mine,
        LocalDateTime createdAt) {
}
