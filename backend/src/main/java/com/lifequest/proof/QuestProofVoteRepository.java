package com.lifequest.proof;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 연관 식별자는 {@code Post_Id}처럼 밑줄로 경로를 끊어 적는다. {@code PostId}로 붙여 쓰면
 * Spring Data가 {@code post.id} 경로 대신 {@code postId}라는 없는 속성을 찾아
 * 부팅이 아니라 <b>호출 시점</b>에 JPQL 문법 오류로 터진다.
 */
public interface QuestProofVoteRepository extends JpaRepository<QuestProofVote, Long> {

    boolean existsByPost_IdAndVoter_Id(Long postId, Long voterId);

    Optional<QuestProofVote> findByPost_IdAndVoter_Id(Long postId, Long voterId);

    /**
     * 피드 한 페이지에서 내가 이미 던진 표를 한 번에 읽는다. 카드마다 개별 조회하면 페이지
     * 크기만큼 질의가 늘어난다. 카드가 "내가 무엇을 골랐는지"까지 보여주므로 투표 여부가
     * 아니라 선택지 자체가 필요하다.
     */
    List<QuestProofVote> findByVoter_IdAndPost_IdIn(Long voterId, Collection<Long> postIds);
}
