package com.lifequest.collection;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

interface AchievementStepRepository extends JpaRepository<AchievementStep, Long> {
    List<AchievementStep> findAllByOrderByAchievementIdAscStepNoAsc();
}
