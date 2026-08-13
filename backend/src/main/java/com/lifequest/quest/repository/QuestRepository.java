package com.lifequest.quest.repository;

import com.lifequest.quest.domain.Quest;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface QuestRepository extends JpaRepository<Quest, Long> {

    /**
     * 배정 풀 후보: 비활성(is_active=false)과 <b>개인 소유 퀘스트</b>를 제외한다.
     *
     * <p>{@code owner_user_id IS NULL} 조건이 빠지면 사용자가 고른 AI 주간 퀘스트가 다른 모든
     * 사용자의 추첨 풀에 들어간다 — 남이 만든 개인 퀘스트가 내게 배정된다. 배정은 확률 추출이라
     * 그런 행이 섞여도 예외가 나지 않고 그냥 배정되므로, 조건이 아니라 결과로는 드러나지 않는다.
     */
    List<Quest> findByActiveTrueAndOwnerUserIdIsNull();

    /**
     * 어드민 카탈로그 목록. 개인 AI 퀘스트를 제외한다.
     *
     * <p>제외하지 않으면 정렬이 {@code createdAt DESC}라 <b>1페이지가 통째로 사용자 개인
     * 퀘스트로 덮인다</b> — 카탈로그 관리 화면이 사실상 못 쓰게 된다.
     */
    Page<Quest> findByOwnerUserIdIsNull(Pageable pageable);

    /**
     * 어드민 단건 조회. 목록만 막으면 부족하다 — 수정·비활성화는 id만 알면 되는 경로라
     * 개인 AI 퀘스트가 카탈로그 관리 대상에 섞인다.
     */
    Optional<Quest> findByIdAndOwnerUserIdIsNull(Long id);
    long countByActiveTrue();

    long countByCadence(com.lifequest.quest.domain.QuestCadence cadence);

    @Query("""
            select avg(q.expReward) from Quest q
            where q.active = true and q.ownerUserId is null
            """)
    Double averageExpRewardForPublicActiveQuests();
}
