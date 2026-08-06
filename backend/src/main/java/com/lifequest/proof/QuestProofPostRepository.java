package com.lifequest.proof;

import com.lifequest.proof.dto.ProofCandidateResponse;
import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * 피드 질의는 셋 다 {@code id} 커서 페이징이다. {@code created_at}이 아니라 {@code id}를
 * 커서로 쓰는 이유는 같은 시각에 등록된 게시물이 있으면 동순위 순서가 페이지마다 달라져
 * 한 건이 두 페이지에 나오고 다른 건이 빠지기 때문이다.
 *
 * <p>어느 질의도 {@code photos}를 JOIN FETCH하지 않는다. 컬렉션을 함께 가져오면 결과 행이
 * 사진 수만큼 불어나 LIMIT이 게시물이 아니라 사진을 세게 되고, Hibernate가 페이징을 메모리로
 * 옮긴다. 사진은 {@link QuestProofPhotoRepository}로 게시물 ID 묶음마다 한 번에 읽는다.
 *
 * <p>조회 질의는 모두 {@code deletedAt IS NULL}을 건다. 삭제된 게시물의 행이 남는 이유는
 * {@link #existsByQuestCompletionId}가 계속 참을 돌려주어야 하기 때문이다(V14).
 */
public interface QuestProofPostRepository extends JpaRepository<QuestProofPost, Long> {

    /**
     * 삭제된 게시물까지 센다. 완료 기록은 한 번 쓰면 다시 쓸 수 없다 — 지웠다 다시 올리는
     * 경로가 열리면 같은 완료로 투표 EXP를 반복 수확할 수 있다.
     */
    boolean existsByQuestCompletionId(Long questCompletionId);

    /**
     * 카운터를 바꾸는 경로(투표·댓글·삭제)가 쓰는 잠금 조회.
     *
     * <p>표 수는 엔티티 필드 증가로 갱신되므로, 잠그지 않으면 두 요청이 같은 값을 읽고 같은
     * 값을 쓰는 잃어버린 갱신이 일어난다 — 투표는 2건인데 카운터는 1이 되고, 판정도 그만큼
     * 늦거나 아예 뒤집힌다.
     *
     * <p>{@link #findDetailById}와 달리 JOIN FETCH를 쓰지 않는 것이 중요하다. 조인한 채로
     * 잠그면 작성자의 {@code users} 행까지 잠기는데, 투표자는 자기 {@code users} 행을 이미
     * 잠근 상태라 서로의 사용자 행을 기다리는 교착이 생길 수 있다.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT p FROM QuestProofPost p WHERE p.id = :postId AND p.deletedAt IS NULL")
    Optional<QuestProofPost> findByIdForUpdate(@Param("postId") Long postId);

    @Query("""
            SELECT p FROM QuestProofPost p
            JOIN FETCH p.author
            JOIN FETCH p.quest
            WHERE p.id = :postId AND p.deletedAt IS NULL
            """)
    Optional<QuestProofPost> findDetailById(@Param("postId") Long postId);

    @Query("""
            SELECT p FROM QuestProofPost p
            JOIN FETCH p.author
            JOIN FETCH p.quest
            WHERE p.deletedAt IS NULL
              AND (:cursor IS NULL OR p.id < :cursor)
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
              AND p.deletedAt IS NULL
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
              AND p.deletedAt IS NULL
              AND (:cursor IS NULL OR p.id < :cursor)
            ORDER BY p.id DESC
            """)
    List<QuestProofPost> findMine(
            @Param("userId") Long userId, @Param("cursor") Long cursor, Pageable pageable);

    /**
     * 아직 게시물을 올리지 않은 내 완료 기록. 작성 화면의 퀘스트 선택 목록이다.
     *
     * <p>{@code NOT EXISTS}에 {@code deletedAt} 조건을 넣지 않는 것이 요점이다 — 삭제한
     * 게시물의 완료 기록은 후보로 돌아오지 않는다.
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
