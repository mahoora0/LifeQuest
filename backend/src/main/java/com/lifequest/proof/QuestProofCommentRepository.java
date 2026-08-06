package com.lifequest.proof;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface QuestProofCommentRepository extends JpaRepository<QuestProofComment, Long> {

    @Query("""
            SELECT c FROM QuestProofComment c
            JOIN FETCH c.author
            WHERE c.post.id = :postId
            ORDER BY c.id ASC
            """)
    List<QuestProofComment> findByPostId(@Param("postId") Long postId);
}
