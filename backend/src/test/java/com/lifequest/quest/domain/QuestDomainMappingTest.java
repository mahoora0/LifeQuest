package com.lifequest.quest.domain;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.lifequest.quest.repository.QuestCompletionRepository;
import com.lifequest.quest.repository.QuestRepository;
import com.lifequest.quest.repository.UserDailyQuestRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

/**
 * 퀘스트 도메인 엔티티가 Flyway로 생성된 스키마(V2)와 정확히 매핑되는지 확인하는 라운드트립 스모크 테스트.
 *
 * <p>매핑·파생 쿼리 동작만 검증한다. 완료 멱등성(UNIQUE 위반)·GPS 판정·배정 같은 비즈니스 로직 검증은
 * 서비스 계층 PR에서 다룬다.
 */
@SpringBootTest
@ActiveProfiles("test")
@Transactional
class QuestDomainMappingTest {

    @Autowired
    private QuestRepository questRepository;

    @Autowired
    private UserDailyQuestRepository userDailyQuestRepository;

    @Autowired
    private QuestCompletionRepository questCompletionRepository;

    @PersistenceContext
    private EntityManager em;

    private Quest persistLocationQuest() {
        Quest quest = new Quest(
                "서울숲 방문", "서울숲을 산책하세요", QuestGrade.RARE, CompletionType.LOCATION,
                30, "서울숲", new BigDecimal("37.5445"), new BigDecimal("127.0374"),
                100, null, QuestCreator.SYSTEM, true);
        return questRepository.save(quest);
    }

    @Test
    void quest_저장_후_모든_컬럼이_왕복_매핑된다() {
        Quest saved = persistLocationQuest();
        em.flush();
        em.clear();

        Quest found = questRepository.findById(saved.getId()).orElseThrow();
        assertEquals("서울숲 방문", found.getTitle());
        assertEquals(QuestGrade.RARE, found.getGrade());
        assertEquals(CompletionType.LOCATION, found.getCompletionType());
        assertEquals(QuestCreator.SYSTEM, found.getCreatedBy());
        assertEquals(30, found.getExpReward());
        assertEquals(100, found.getRadiusM());
        assertEquals(0, new BigDecimal("37.5445").compareTo(found.getLatitude()));
        assertEquals(0, new BigDecimal("127.0374").compareTo(found.getLongitude()));
        assertTrue(found.isActive());
        assertTrue(found.isLocationBased());
        assertNotNull(found.getCreatedAt(), "@PrePersist가 created_at을 채워야 한다");
    }

    @Test
    void quest_비활성은_배정풀_조회에서_제외된다() {
        persistLocationQuest();
        Quest inactive = new Quest(
                "종료된 퀘스트", null, QuestGrade.NORMAL, CompletionType.SELF_REPORT,
                10, null, null, null, null, null, QuestCreator.ADMIN, false);
        questRepository.save(inactive);
        em.flush();
        em.clear();

        assertTrue(questRepository.findByActiveTrue().stream().allMatch(Quest::isActive));
        assertTrue(questRepository.findByActiveTrue().stream().noneMatch(q -> "종료된 퀘스트".equals(q.getTitle())));
    }

    @Test
    void userDailyQuest_저장시_상태가_ASSIGNED로_시작하고_오늘조회로_찾힌다() {
        Quest quest = persistLocationQuest();
        LocalDate today = LocalDate.now();
        UserDailyQuest assignment = new UserDailyQuest(
                1L, quest.getId(), today, today.atTime(23, 59, 59));
        userDailyQuestRepository.save(assignment);
        em.flush();
        em.clear();

        UserDailyQuest found = userDailyQuestRepository.findById(assignment.getId()).orElseThrow();
        assertEquals(DailyQuestStatus.ASSIGNED, found.getStatus());
        assertEquals(quest.getId(), found.getQuestId());
        assertEquals(1, userDailyQuestRepository.findByUserIdAndAssignedDate(1L, today).size());
        assertTrue(userDailyQuestRepository.existsByUserIdAndQuestIdAndAssignedDate(1L, quest.getId(), today));
    }

    @Test
    void questCompletion_LOCATION_인증데이터가_왕복_매핑되고_배정ID로_조회된다() {
        Quest quest = persistLocationQuest();
        LocalDate today = LocalDate.now();
        UserDailyQuest assignment = userDailyQuestRepository.save(
                new UserDailyQuest(1L, quest.getId(), today, today.atTime(23, 59, 59)));
        em.flush();

        QuestCompletion completion = new QuestCompletion(
                assignment.getId(), 1L, quest.getId(),
                new BigDecimal("37.5446"), new BigDecimal("127.0375"),
                new BigDecimal("18.30"), new BigDecimal("12.50"), LocalDateTime.now());
        questCompletionRepository.save(completion);
        em.flush();
        em.clear();

        QuestCompletion found =
                questCompletionRepository.findByUserDailyQuestId(assignment.getId()).orElseThrow();
        assertEquals(quest.getId(), found.getQuestId());
        assertEquals(0, new BigDecimal("18.30").compareTo(found.getDistanceM()));
        assertEquals(0, new BigDecimal("12.50").compareTo(found.getAccuracyM()));
        assertEquals(1,
                questCompletionRepository.findByUserIdOrderByCompletedAtDesc(1L, PageRequest.of(0, 20))
                        .getTotalElements());
    }

    @Test
    void questCompletion_SELF_REPORT는_위치항목이_null로_저장된다() {
        Quest quest = new Quest(
                "책 한 권 읽기", null, QuestGrade.NORMAL, CompletionType.SELF_REPORT,
                15, null, null, null, null, null, QuestCreator.SYSTEM, true);
        questRepository.save(quest);
        LocalDate today = LocalDate.now();
        UserDailyQuest assignment = userDailyQuestRepository.save(
                new UserDailyQuest(2L, quest.getId(), today, today.atTime(23, 59, 59)));
        em.flush();

        QuestCompletion completion = new QuestCompletion(
                assignment.getId(), 2L, quest.getId(), null, null, null, null, LocalDateTime.now());
        questCompletionRepository.save(completion);
        em.flush();
        em.clear();

        QuestCompletion found =
                questCompletionRepository.findByUserDailyQuestId(assignment.getId()).orElseThrow();
        assertEquals(null, found.getVerifiedLatitude());
        assertEquals(null, found.getDistanceM());
        assertFalse(quest.isLocationBased());
    }
}
