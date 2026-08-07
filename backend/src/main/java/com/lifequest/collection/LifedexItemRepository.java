package com.lifequest.collection;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

interface LifedexItemRepository extends JpaRepository<LifedexItem, Long> {
    List<LifedexItem> findAllByOrderByCategoryIdAscDisplayOrderAsc();
    List<LifedexItem> findByCategoryIdOrderByDisplayOrderAsc(Long categoryId);
    long countByCategoryId(Long categoryId);
}
