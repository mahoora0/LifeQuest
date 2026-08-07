package com.lifequest.collection;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

interface UserLifedexRepository extends JpaRepository<UserLifedex, Long> {
    List<UserLifedex> findByUserId(Long userId);

    long countByUserId(Long userId);

    @Query(value = """
            SELECT li.category_id
            FROM lifedex_items li
            LEFT JOIN user_lifedex ul
              ON ul.lifedex_item_id = li.id
             AND ul.user_id = :userId
            GROUP BY li.category_id
            HAVING COUNT(li.id) = COUNT(ul.id)
            """, nativeQuery = true)
    List<Long> findCompletedCategoryIds(@Param("userId") Long userId);

    /** UNIQUE(user_id, lifedex_item_id)와 함께 동시 완료 요청의 중복 수집을 막는다. */
    @Modifying
    @Query(value = """
            INSERT IGNORE INTO user_lifedex (user_id, lifedex_item_id, collected_at)
            VALUES (:userId, :lifedexItemId, CURRENT_TIMESTAMP(6))
            """, nativeQuery = true)
    int insertIfAbsent(
            @Param("userId") Long userId,
            @Param("lifedexItemId") Long lifedexItemId);
}
