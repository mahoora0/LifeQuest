package com.lifequest.quest.repository;

import com.lifequest.quest.domain.Quest;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface QuestRepository extends JpaRepository<Quest, Long> {

    /** 배정 풀 후보: 비활성(is_active=false) 퀘스트는 제외한다. */
    List<Quest> findByActiveTrue();
}
