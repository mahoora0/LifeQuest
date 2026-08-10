package com.lifequest.collection;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

interface AchievementRepository extends JpaRepository<Achievement, Long> {
    List<Achievement> findAllByOrderByDisplayOrderAsc();
}
