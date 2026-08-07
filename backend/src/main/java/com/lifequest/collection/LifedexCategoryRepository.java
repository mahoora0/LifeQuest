package com.lifequest.collection;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

interface LifedexCategoryRepository extends JpaRepository<LifedexCategory, Long> {
    List<LifedexCategory> findAllByOrderByDisplayOrderAsc();
}
