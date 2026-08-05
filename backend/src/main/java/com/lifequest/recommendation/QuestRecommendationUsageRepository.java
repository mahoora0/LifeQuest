package com.lifequest.recommendation;
import jakarta.persistence.LockModeType;import java.time.LocalDate;import java.util.Optional;import org.springframework.data.jpa.repository.*;import org.springframework.data.repository.query.Param;
public interface QuestRecommendationUsageRepository extends JpaRepository<QuestRecommendationUsage,Long>{
 @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select u from QuestRecommendationUsage u where u.user.id=:userId and u.usageDate=:date") Optional<QuestRecommendationUsage> findForUpdate(@Param("userId") Long userId,@Param("date") LocalDate date);
}
