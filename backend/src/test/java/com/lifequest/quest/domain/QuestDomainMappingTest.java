package com.lifequest.quest.domain;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.lifequest.quest.repository.QuestCompletionRepository;
import com.lifequest.quest.repository.QuestRepository;
import com.lifequest.quest.repository.UserDailyQuestRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.PersistenceException;
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
 * 퀘스트 도메인 엔티티가 Flyway 마이그레이션으로 생성된 퀘스트 스키마와 정확히 매핑되는지 확인하는
 * 라운드트립 스모크 테스트.
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
                "서울숲 방문", "서울숲을 산책하세요", QuestGrade.RARE, QuestCadence.WEEKLY,
                CompletionType.LOCATION, 30, "서울숲", new BigDecimal("37.5445"),
                new BigDecimal("127.0374"), 100, null, QuestCreator.SYSTEM, true);
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
        assertEquals(QuestCadence.WEEKLY, found.getCadence(),
                "cadence는 DEFAULT 'DAILY'로 덮이지 않고 지정한 값이 그대로 저장되어야 한다");
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
    void quest_비활성은_배정_풀_조회에서_제외된다() {
        persistLocationQuest();
        Quest inactive = new Quest(
                "종료된 퀘스트", null, QuestGrade.NORMAL, QuestCadence.DAILY,
                CompletionType.SELF_REPORT, 10, null, null, null, null, null,
                QuestCreator.ADMIN, false);
        questRepository.save(inactive);
        em.flush();
        em.clear();

        assertTrue(questRepository.findByActiveTrue().stream().allMatch(Quest::isActive));
        assertTrue(questRepository.findByActiveTrue().stream().noneMatch(q -> "종료된 퀘스트".equals(q.getTitle())));
    }

    @Test
    void quest_LOCATION인데_좌표나_반경이_없으면_생성이_거부된다() {
        assertThrows(IllegalArgumentException.class, () -> new Quest(
                "좌표 없는 위치 퀘스트", null, QuestGrade.NORMAL, QuestCadence.DAILY,
                CompletionType.LOCATION, 10, "어딘가", null, null, 100, null,
                QuestCreator.ADMIN, true),
                "좌표 없는 LOCATION 퀘스트는 GPS 판정이 불가능하다");

        assertThrows(IllegalArgumentException.class, () -> new Quest(
                "반경 없는 위치 퀘스트", null, QuestGrade.NORMAL, QuestCadence.DAILY,
                CompletionType.LOCATION, 10, "어딘가", new BigDecimal("37.5"),
                new BigDecimal("127.0"), null, null, QuestCreator.ADMIN, true),
                "radius_m이 null이면 판정에서 언박싱 NPE가 난다");

        assertThrows(IllegalArgumentException.class, () -> new Quest(
                "반경 0인 위치 퀘스트", null, QuestGrade.NORMAL, QuestCadence.DAILY,
                CompletionType.LOCATION, 10, "어딘가", new BigDecimal("37.5"),
                new BigDecimal("127.0"), 0, null, QuestCreator.ADMIN, true),
                "반경 0은 어떤 위치도 통과하지 못해 완료 불가 상태가 된다");
    }

    @Test
    void quests_CHECK_제약이_애플리케이션을_우회한_LOCATION_행도_막는다() {
        assertThrows(PersistenceException.class, () -> {
            em.createNativeQuery("""
                    INSERT INTO quests
                        (title, grade, completion_type, exp_reward, created_by, is_active, created_at)
                    VALUES ('우회 삽입', 'NORMAL', 'LOCATION', 10, 'ADMIN', TRUE, CURRENT_TIMESTAMP(6))
                    """).executeUpdate();
            em.flush();
        }, "ck_quests_location_verifiable이 좌표 없는 LOCATION 행을 거부해야 한다");
    }

    @Test
    void userDailyQuest_저장하면_ASSIGNED로_시작하고_오늘_조회에_포함된다() {
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
                assignment,
                new BigDecimal("37.5446"), new BigDecimal("127.0375"),
                new BigDecimal("18.30"), new BigDecimal("12.50"), LocalDateTime.now());
        questCompletionRepository.save(completion);
        em.flush();
        em.clear();

        QuestCompletion found =
                questCompletionRepository.findByUserDailyQuestId(assignment.getId()).orElseThrow();
        assertEquals(quest.getId(), found.getQuestId());
        assertEquals(1L, found.getUserId(), "user_id는 배정 건에서 파생되어야 한다");
        assertEquals(0, new BigDecimal("18.30").compareTo(found.getDistanceM()));
        assertEquals(0, new BigDecimal("12.50").compareTo(found.getAccuracyM()));
        assertEquals(1,
                questCompletionRepository.findByUserIdOrderByCompletedAtDescIdDesc(1L, PageRequest.of(0, 20))
                        .getTotalElements());
    }

    @Test
    void questCompletion_완료_시각이_마이크로초까지_보존된다() {
        Quest quest = persistLocationQuest();
        LocalDate today = LocalDate.now();
        UserDailyQuest assignment = userDailyQuestRepository.save(
                new UserDailyQuest(3L, quest.getId(), today, today.atTime(23, 59, 59)));
        em.flush();

        // 소수점 초가 잘리면 완료 이력의 순서가 무너지고, expires_at은 반올림으로 만료 경계가 밀린다.
        LocalDateTime completedAt = LocalDateTime.of(2026, 7, 27, 12, 0, 0, 700_000_000);
        questCompletionRepository.save(
                new QuestCompletion(assignment, null, null, null, null, completedAt));
        em.flush();
        em.clear();

        QuestCompletion found =
                questCompletionRepository.findByUserDailyQuestId(assignment.getId()).orElseThrow();
        assertEquals(completedAt, found.getCompletedAt(),
                "completed_at은 DATETIME(6)이어야 하고 소수점 초가 보존되어야 한다");
    }

    @Test
    void questCompletion_같은_시각_완료_건도_페이지_경계에서_중복되지_않는다() {
        LocalDate today = LocalDate.now();
        LocalDateTime sameInstant = LocalDateTime.of(2026, 7, 27, 9, 0, 0, 0);
        for (int i = 0; i < 2; i++) {
            Quest quest = persistLocationQuest();
            UserDailyQuest assignment = userDailyQuestRepository.save(
                    new UserDailyQuest(5L, quest.getId(), today, today.atTime(23, 59, 59)));
            em.flush();
            questCompletionRepository.save(
                    new QuestCompletion(assignment, null, null, null, null, sameInstant));
        }
        em.flush();
        em.clear();

        Long firstPage = questCompletionRepository
                .findByUserIdOrderByCompletedAtDescIdDesc(5L, PageRequest.of(0, 1))
                .getContent().get(0).getId();
        Long secondPage = questCompletionRepository
                .findByUserIdOrderByCompletedAtDescIdDesc(5L, PageRequest.of(1, 1))
                .getContent().get(0).getId();

        assertNotEquals(firstPage, secondPage,
                "완료 시각이 같아도 페이지 경계가 안정적이어야 한다 — 보조 정렬키가 없으면 한 건이 두 번 보이고 다른 건이 빠진다");
    }

    @Test
    void questCompletion_저장되지_않은_배정_건으로는_만들_수_없다() {
        Quest quest = persistLocationQuest();
        LocalDate today = LocalDate.now();
        UserDailyQuest unsaved =
                new UserDailyQuest(4L, quest.getId(), today, today.atTime(23, 59, 59));

        assertThrows(IllegalArgumentException.class, () -> new QuestCompletion(
                unsaved, null, null, null, null, LocalDateTime.now()),
                "배정 ID가 없으면 완료 기록이 어느 배정에 붙는지 정할 수 없다");
    }

    @Test
    void questCompletion_SELF_REPORT는_위치_항목이_null로_저장된다() {
        Quest quest = new Quest(
                "책 한 권 읽기", null, QuestGrade.NORMAL, QuestCadence.DAILY,
                CompletionType.SELF_REPORT, 15, null, null, null, null, null,
                QuestCreator.SYSTEM, true);
        questRepository.save(quest);
        LocalDate today = LocalDate.now();
        UserDailyQuest assignment = userDailyQuestRepository.save(
                new UserDailyQuest(2L, quest.getId(), today, today.atTime(23, 59, 59)));
        em.flush();

        QuestCompletion completion =
                new QuestCompletion(assignment, null, null, null, null, LocalDateTime.now());
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
