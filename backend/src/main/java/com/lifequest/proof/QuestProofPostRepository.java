package com.lifequest.proof;

import com.lifequest.proof.dto.ProofCandidateResponse;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * 피드 질의는 셋 다 {@code id} 역순 커서 페이징이다. {@code created_at}이 아니라 {@code id}를
 * 커서로 쓰는 이유는 같은 시각에 등록된 게시물이 있으면 동순위 순서가 페이지마다 달라져
 * 한 건이 두 페이지에 나오고 다른 건이 빠지기 때문이다.
 *
 * <p>어느 질의도 {@code photos}를 JOIN FETCH하지 않는다. 컬렉션을 함께 가져오면 결과 행이
 * 사진 수만큼 불어나 LIMIT이 게시물이 아니라 사진을 세게 되고, Hibernate가 페이징을 메모리로
 * 옮긴다. 사진은 {@link QuestProofPhotoRepository}로 게시물 ID 묶음마다 한 번에 읽는다.
 */
public interface QuestProofPostRepository extends JpaRepository<QuestProofPost, Long> {

    boolean existsByQuestCompletionId(Long questCompletionId);

    @Query("""
            SELECT p FROM QuestProofPost p
            JOIN FETCH p.author
            JOIN FETCH p.quest
            WHERE p.id = :postId
            """)
    Optional<QuestProofPost> findDetailById(@Param("postId") Long postId);

    @Query("""
            SELECT p FROM QuestProofPost p
            JOIN FETCH p.author
            JOIN FETCH p.quest
            WHERE (:cursor IS NULL OR p.id < :cursor)
            ORDER BY p.id DESC
            """)
    List<QuestProofPost> findFeed(@Param("cursor") Long cursor, Pageable pageable);

    /**
     * 내가 아직 판단하지 않은, 아직 판정되지 않은 남의 게시물. 홈 섹션과 피드의 기본 탭이
     * 쓴다. 최신순 피드를 그대로 쓰면 이미 확정된 게시물이 위를 차지해서, 사용자 수가 적을 때
     * 표가 부족한 게시물이 영원히 아래로 밀린다 — 그 게시물이야말로 표가 필요한 쪽이다.
     * 오래된 순으로 주는 것도 같은 이유다.
     */
    @Query("""
            SELECT p FROM QuestProofPost p
            JOIN FETCH p.author
            JOIN FETCH p.quest
            WHERE p.status = com.lifequest.proof.ProofPostStatus.VOTING
              AND p.author.id <> :userId
              AND NOT EXISTS (
                  SELECT 1 FROM QuestProofVote v
                  WHERE v.post = p AND v.voter.id = :userId)
              AND (:cursor IS NULL OR p.id > :cursor)
            ORDER BY p.id ASC
            """)
    List<QuestProofPost> findNeedingVotes(
            @Param("userId") Long userId, @Param("cursor") Long cursor, Pageable pageable);

    @Query("""
            SELECT p FROM QuestProofPost p
            JOIN FETCH p.author
            JOIN FETCH p.quest
            WHERE p.author.id = :userId
              AND (:cursor IS NULL OR p.id < :cursor)
            ORDER BY p.id DESC
            """)
    List<QuestProofPost> findMine(
            @Param("userId") Long userId, @Param("cursor") Long cursor, Pageable pageable);

    /**
     * 아직 게시물을 올리지 않은 내 완료 기록. 작성 화면의 퀘스트 선택 목록이다.
     *
     * <p>{@code QuestCompletion}은 퀘스트 도메인 소유라 {@code quest_id}를 FK 없는 컬럼으로만
     * 들고 있다. 매핑된 연관이 없으므로 {@code ON}을 명시한 엔티티 조인으로 제목을 가져온다.
     */
    @Query("""
            SELECT new com.lifequest.proof.dto.ProofCandidateResponse(
                c.id, q.id, q.title, q.grade, c.completedAt)
            FROM QuestCompletion c
            JOIN Quest q ON q.id = c.questId
            WHERE c.userId = :userId
              AND NOT EXISTS (
                  SELECT 1 FROM QuestProofPost p WHERE p.questCompletionId = c.id)
            ORDER BY c.id DESC
            """)
    List<ProofCandidateResponse> findPostableCompletions(
            @Param("userId") Long userId, Pageable pageable);
}
