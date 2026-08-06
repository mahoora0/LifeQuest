package com.lifequest.proof;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface QuestProofPhotoRepository extends JpaRepository<QuestProofPhoto, Long> {

    /**
     * 피드 한 페이지의 사진을 한 번에 읽는다. 게시물마다 지연 로딩을 트리거하면 페이지 크기만큼
     * 질의가 늘어난다(N+1).
     */
    @Query("""
            SELECT ph FROM QuestProofPhoto ph
            WHERE ph.post.id IN :postIds
            ORDER BY ph.post.id ASC, ph.sortOrder ASC
            """)
    List<QuestProofPhoto> findByPostIds(@Param("postIds") Collection<Long> postIds);
}
