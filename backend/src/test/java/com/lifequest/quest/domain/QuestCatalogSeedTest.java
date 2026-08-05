package com.lifequest.quest.domain;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.lifequest.quest.repository.QuestRepository;
import java.math.BigDecimal;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.LongStream;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

/**
 * V6가 넣은 초기 퀘스트 카탈로그(id 1~42)가 업무 규칙의 불변식을 지키는지 검증한다.
 *
 * <p>시드는 SQL 리터럴 168개로 이루어져 있어 사람 눈으로는 등급별 EXP 구간 이탈이나 위경도 뒤바뀜 같은
 * 오타가 걸러지지 않는다. 배정 서비스가 없는 지금은 잘못된 행이 들어가도 드러날 경로가 없고,
 * 배정을 붙인 뒤에야 특정 퀘스트만 완료 불가로 나타난다. 그 전에 여기서 막는다.
 *
 * <p>조회 대상을 id 1~42로 못박아 다른 테스트가 만든 행에 영향받지 않게 한다.
 */
@SpringBootTest
@ActiveProfiles("test")
@Transactional
class QuestCatalogSeedTest {

    /** V6가 명시한 시드 id 범위. 업적의 target_quest_id가 참조하므로 고정이다. */
    private static final long FIRST_SEED_ID = 1L;
    private static final long LAST_SEED_ID = 42L;

    /** docs/05-business-rules.md §2의 등급별 EXP 범위. */
    private static final Map<QuestGrade, int[]> EXP_RANGE = new EnumMap<>(Map.of(
            QuestGrade.NORMAL, new int[] {10, 20},
            QuestGrade.RARE, new int[] {30, 50},
            QuestGrade.EPIC, new int[] {60, 100},
            QuestGrade.LEGENDARY, new int[] {150, 300}));

    /** docs/05-business-rules.md §3-1의 가장 넓은 반경 구간 상한. */
    private static final int MAX_RADIUS_M = 500;

    @Autowired
    private QuestRepository questRepository;

    private List<Quest> seededQuests() {
        return questRepository.findAllById(
                LongStream.rangeClosed(FIRST_SEED_ID, LAST_SEED_ID).boxed().toList());
    }

    @Test
    void 시드_퀘스트가_id_누락_없이_전부_적재된다() {
        assertEquals(LAST_SEED_ID - FIRST_SEED_ID + 1, seededQuests().size(),
                "id 1~42가 모두 있어야 한다 — 업적의 target_quest_id가 이 번호를 참조한다");
    }

    /**
     * V15가 37·38을 비활성으로 내리기 전까지 이 테스트는 "시드는 전부 배정 풀에 들어간다"였다.
     * 이제 예외가 둘 생겼으므로 단언을 느슨하게 풀면 실수로 비활성된 퀘스트를 잡지 못한다
     * — 비활성은 조용하다. 그 퀘스트는 예외도 로그도 없이 배정 후보에서 사라질 뿐이다.
     *
     * <p>그래서 "전부 활성"이 아니라 <b>비활성 목록을 정확히 고정</b>한다. 셋째가 늘어나면 실패한다.
     */
    @Test
    void 배정_풀에서_빠진_시드는_의도된_비활성_2건뿐이다() {
        List<Quest> pool = questRepository.findByActiveTrue();

        assertEquals(
                Set.of(37L, 38L),
                seededQuests().stream()
                        .filter(quest -> !quest.isActive())
                        .map(Quest::getId)
                        .collect(Collectors.toSet()),
                "비활성 시드는 37(한 달 예산 점검)·38(건강검진)뿐이어야 한다 — "
                        + "월간 폐지로 주 단위 반복이 어색해진 둘만 내렸다(V15)");

        for (Quest quest : seededQuests()) {
            assertEquals(quest.isActive(), pool.contains(quest),
                    quest.getTitle() + ": is_active와 배정 풀 포함 여부가 어긋난다");
        }
    }

    @Test
    void 등급별_EXP가_업무_규칙_범위를_벗어나지_않는다() {
        for (Quest quest : seededQuests()) {
            int[] range = EXP_RANGE.get(quest.getGrade());
            assertNotNull(range, quest.getGrade() + "의 EXP 범위가 규칙서에 없다");
            assertTrue(quest.getExpReward() >= range[0] && quest.getExpReward() <= range[1],
                    "%s: %s 등급의 EXP는 %d~%d여야 하는데 %d다"
                            .formatted(quest.getTitle(), quest.getGrade(),
                                    range[0], range[1], quest.getExpReward()));
        }
    }

    @Test
    void 모든_등급과_주기에_배정_후보가_존재한다() {
        List<Quest> seeded = seededQuests();

        for (QuestGrade grade : QuestGrade.values()) {
            assertTrue(seeded.stream().anyMatch(q -> q.getGrade() == grade),
                    grade + " 등급 후보가 없으면 등급별 배정 확률(§2)이 성립하지 않는다");
        }
        for (QuestCadence cadence : QuestCadence.values()) {
            assertTrue(seeded.stream().anyMatch(q -> q.getCadence() == cadence),
                    cadence + " 주기 후보가 없으면 목록 화면의 해당 필터가 항상 비어 보인다");
        }
    }

    /**
     * 마이그레이션 머리말은 등급·주기 분포를 수치로 적어 둔다. 이 수치는 트랙별 배정 확률을 세우는
     * 근거이자 목록 화면의 주기 필터가 얼마나 채워지는지를 가늠하는 기준이다.
     *
     * <p>후보 존재 여부만 검사하면 분포가 통째로 달라져도 통과하므로 실제 건수를 고정한다.
     * 시드를 늘리거나 등급을 바꾸면 이 테스트가 먼저 실패해 머리말 수치를 함께 갱신하게 만든다.
     *
     * <p>등급 분포의 출처는 V6 머리말이고 주기 분포는 V15 머리말이다 — V15가 37~42의 주기를 옮겼고,
     * 이미 적용된 V6는 체크섬 때문에 고칠 수 없어 머리말이 낡은 채 남아 있다.
     * 두 수치 모두 <b>비활성 2건을 포함한</b> id 1~42 전체 기준이다.
     */
    @Test
    void 시드_분포가_마이그레이션_머리말의_수치와_일치한다() {
        assertEquals(
                Map.of(QuestGrade.NORMAL, 19L, QuestGrade.RARE, 14L,
                        QuestGrade.EPIC, 7L, QuestGrade.LEGENDARY, 2L),
                seededQuests().stream()
                        .collect(Collectors.groupingBy(Quest::getGrade, Collectors.counting())),
                "등급 분포가 V6 머리말과 다르다 — 시드를 고쳤다면 머리말 수치도 함께 갱신해야 한다");

        assertEquals(
                Map.of(QuestCadence.DAILY, 24L, QuestCadence.WEEKLY, 18L),
                seededQuests().stream()
                        .collect(Collectors.groupingBy(Quest::getCadence, Collectors.counting())),
                "주기 분포가 V15 머리말과 다르다 — 주간 18건은 기존 12건에 재분류된 37~42를 더한 값이다");
    }

    @Test
    void LOCATION_퀘스트는_전부_GPS로_판정할_수_있다() {
        List<Quest> located = seededQuests().stream().filter(Quest::isLocationBased).toList();
        assertFalse(located.isEmpty(), "위치 인증 퀘스트가 하나도 없으면 GPS 인증 경로를 시연할 수 없다");

        for (Quest quest : located) {
            assertNotNull(quest.getLatitude(), quest.getTitle() + ": 위도가 없다");
            assertNotNull(quest.getLongitude(), quest.getTitle() + ": 경도가 없다");
            assertNotNull(quest.getPlaceName(), quest.getTitle() + ": 장소명이 없으면 어디로 갈지 안내할 수 없다");
            assertNotNull(quest.getRadiusM(), quest.getTitle() + ": 반경이 없으면 판정에서 언박싱 NPE가 난다");
            assertTrue(quest.getRadiusM() > 0 && quest.getRadiusM() <= MAX_RADIUS_M,
                    "%s: 반경은 0보다 크고 %dm 이하여야 하는데 %d다"
                            .formatted(quest.getTitle(), MAX_RADIUS_M, quest.getRadiusM()));
        }
    }

    /**
     * 위경도를 뒤바꿔 적는 것은 좌표 시드의 대표적인 오타이고, 눈으로는 잘 보이지 않는다.
     * 대한민국 육지 범위를 벗어나면 어떤 사용자도 반경 안에 들어갈 수 없어 그 퀘스트는 영구히 완료 불가가 된다.
     */
    @Test
    void 좌표가_대한민국_범위를_벗어나지_않는다() {
        BigDecimal minLat = new BigDecimal("33.0");
        BigDecimal maxLat = new BigDecimal("39.0");
        BigDecimal minLng = new BigDecimal("124.0");
        BigDecimal maxLng = new BigDecimal("132.0");

        for (Quest quest : seededQuests().stream().filter(Quest::isLocationBased).toList()) {
            assertTrue(quest.getLatitude().compareTo(minLat) >= 0
                            && quest.getLatitude().compareTo(maxLat) <= 0,
                    quest.getTitle() + ": 위도 " + quest.getLatitude() + "는 대한민국 범위 밖이다");
            assertTrue(quest.getLongitude().compareTo(minLng) >= 0
                            && quest.getLongitude().compareTo(maxLng) <= 0,
                    quest.getTitle() + ": 경도 " + quest.getLongitude() + "는 대한민국 범위 밖이다");
        }
    }

    @Test
    void SELF_REPORT_퀘스트에는_위치_항목이_남아있지_않는다() {
        for (Quest quest : seededQuests().stream().filter(q -> !q.isLocationBased()).toList()) {
            assertNull(quest.getLatitude(), quest.getTitle() + ": 직접 완료인데 위도가 있다");
            assertNull(quest.getLongitude(), quest.getTitle() + ": 직접 완료인데 경도가 있다");
            assertNull(quest.getRadiusM(), quest.getTitle() + ": 직접 완료인데 반경이 있다");
            assertNull(quest.getPlaceName(), quest.getTitle() + ": 직접 완료인데 장소명이 있다");
        }
    }

    /**
     * 하루 배정은 일간 퀘스트에서 나온다. 일간이 전부 위치 인증이면 밖에 나가기 어려운 날
     * 하루치가 통째로 잠기므로, 이동 없이 끝낼 수 있는 후보가 다수를 차지해야 한다.
     */
    @Test
    void 일간_퀘스트는_이동_없이_완료할_수_있는_후보가_다수다() {
        List<Quest> daily = seededQuests().stream()
                .filter(q -> q.getCadence() == QuestCadence.DAILY)
                .toList();
        long selfReport = daily.stream().filter(q -> !q.isLocationBased()).count();

        assertTrue(selfReport * 2 > daily.size(),
                "일간 %d건 중 직접 완료가 %d건뿐이다 — 이동이 어려운 날 배정이 막힌다"
                        .formatted(daily.size(), selfReport));
    }
}
