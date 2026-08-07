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
 * 시드 퀘스트 카탈로그(V6의 id 1~42 + V22의 43~68)가 업무 규칙의 불변식을 지키는지 검증한다.
 *
 * <p>시드는 SQL 리터럴 수백 개로 이루어져 있어 사람 눈으로는 등급별 EXP 구간 이탈이나 위경도 뒤바뀜 같은
 * 오타가 걸러지지 않는다. 잘못된 행이 들어가도 배정에서만 드러나며, 그것도 특정 퀘스트가
 * 완료 불가로 나타나는 형태라 조용하다. 그 전에 여기서 막는다.
 *
 * <p>조회 대상을 id 범위로 못박아 다른 테스트가 만든 행에 영향받지 않게 한다.
 *
 * <p><b>EXP 검사는 두 범위로 갈라져 있다.</b> V22 머리말이 §2 등급별 범위를 의도적으로 벗어난
 * 값을 넣었다고 밝히고 있어(일간 EPIC 45~50 · 주간 NORMAL 25~28), 한 기준으로 재면 확장분이
 * 통째로 실패한다. §2가 갱신되면 두 테스트를 합친다.
 */
@SpringBootTest
@ActiveProfiles("test")
@Transactional
class QuestCatalogSeedTest {

    /** V6가 명시한 시드 id 범위. 업적의 target_quest_id가 참조하므로 고정이다. */
    private static final long FIRST_SEED_ID = 1L;
    private static final long BASE_SEED_LAST_ID = 42L;

    /** V22 확장분의 마지막 id. 추가는 계속 뒤에 붙는다(V22 머리말). */
    private static final long LAST_SEED_ID = 68L;

    /** docs/05-business-rules.md §2의 등급별 EXP 범위. */
    private static final Map<QuestGrade, int[]> EXP_RANGE = new EnumMap<>(Map.of(
            QuestGrade.NORMAL, new int[] {10, 20},
            QuestGrade.RARE, new int[] {30, 50},
            QuestGrade.EPIC, new int[] {60, 100},
            QuestGrade.LEGENDARY, new int[] {150, 300}));

    /** §2 등급 표 전체의 하한·상한. 확장분은 이 바깥으로 나가지 않는다. */
    private static final int MIN_EXP = 10;
    private static final int MAX_EXP = 300;

    /** docs/05-business-rules.md §3-1의 가장 넓은 반경 구간 상한. */
    private static final int MAX_RADIUS_M = 500;

    @Autowired
    private QuestRepository questRepository;

    private List<Quest> seededQuests() {
        return questRepository.findAllById(
                LongStream.rangeClosed(FIRST_SEED_ID, LAST_SEED_ID).boxed().toList());
    }

    private List<Quest> baseSeededQuests() {
        return questRepository.findAllById(
                LongStream.rangeClosed(FIRST_SEED_ID, BASE_SEED_LAST_ID).boxed().toList());
    }

    private List<Quest> extendedSeededQuests() {
        return questRepository.findAllById(
                LongStream.rangeClosed(BASE_SEED_LAST_ID + 1, LAST_SEED_ID).boxed().toList());
    }

    @Test
    void 시드_퀘스트가_id_누락_없이_전부_적재된다() {
        assertEquals(LAST_SEED_ID - FIRST_SEED_ID + 1, seededQuests().size(),
                "id 1~68이 모두 있어야 한다 — 1~42는 업적의 target_quest_id가 참조하고, "
                        + "43~68은 슬롯 등급 결손을 메우려고 V22이 넣었다");
    }

    /**
     * V20가 37·38을 비활성으로 내리기 전까지 이 테스트는 "시드는 전부 배정 풀에 들어간다"였다.
     * 이제 예외가 둘 생겼으므로 단언을 느슨하게 풀면 실수로 비활성된 퀘스트를 잡지 못한다
     * — 비활성은 조용하다. 그 퀘스트는 예외도 로그도 없이 배정 후보에서 사라질 뿐이다.
     *
     * <p>그래서 "전부 활성"이 아니라 <b>비활성 목록을 정확히 고정</b>한다. 셋째가 늘어나면 실패한다.
     */
    @Test
    void 배정_풀에서_빠진_시드는_의도된_비활성_2건뿐이다() {
        List<Quest> pool = questRepository.findByActiveTrueAndOwnerUserIdIsNull();

        assertEquals(
                Set.of(37L, 38L),
                seededQuests().stream()
                        .filter(quest -> !quest.isActive())
                        .map(Quest::getId)
                        .collect(Collectors.toSet()),
                "비활성 시드는 37(한 달 예산 점검)·38(건강검진)뿐이어야 한다 — "
                        + "월간 폐지로 주 단위 반복이 어색해진 둘만 내렸다(V20)");

        for (Quest quest : seededQuests()) {
            assertEquals(quest.isActive(), pool.contains(quest),
                    quest.getTitle() + ": is_active와 배정 풀 포함 여부가 어긋난다");
        }
    }

    @Test
    void 등급별_EXP가_업무_규칙_범위를_벗어나지_않는다() {
        assertExpWithin(baseSeededQuests(), EXP_RANGE);
    }

    /**
     * 확장분(43~68)은 §2의 등급별 구간을 쓰지 않는다. V22이
     * <b>"트랙이 보상 대역을 정하고 등급이 그 대역 안에서 위치를 정한다"</b>는 방향을 머리말에
     * 명시했고, 실제로 일간 LEGENDARY는 55~60이고 주간 LEGENDARY는 200~220이다.
     *
     * <p>그래서 <b>구간이 아니라 원리를 잰다</b> — 같은 트랙 안에서 등급이 오르면 EXP도 오른다.
     * 구간을 실제 값에 맞춰 다시 적으면 테스트가 시드를 베끼는 것이 되어 아무것도 보장하지 못한다.
     *
     * <p>이 검사는 등급과 EXP가 <b>어긋나는 방향</b>을 잡는다 — LEGENDARY에 NORMAL 값을 적거나
     * 두 등급의 값을 맞바꾸면 대역이 겹쳐 실패한다. 절대 상한은 아래 별도 테스트가 맡는다.
     */
    @Test
    void 확장_시드의_EXP는_트랙_안에서_등급_순서를_지킨다() {
        for (QuestCadence cadence : QuestCadence.values()) {
            List<Quest> track = extendedSeededQuests().stream()
                    .filter(quest -> quest.getCadence() == cadence)
                    .toList();

            int previousMax = 0;
            QuestGrade previousGrade = null;
            for (QuestGrade grade : QuestGrade.values()) {
                List<Quest> ofGrade = track.stream()
                        .filter(quest -> quest.getGrade() == grade)
                        .toList();
                if (ofGrade.isEmpty()) {
                    continue;
                }

                int min = ofGrade.stream().mapToInt(Quest::getExpReward).min().orElseThrow();
                assertTrue(min > previousMax,
                        "%s %s의 최소 EXP %d가 %s의 최대 %d 이하다 — 등급 대역이 겹치면 "
                                .formatted(cadence, grade, min, previousGrade, previousMax)
                                + "상위 등급을 뽑아도 보상이 낮아질 수 있다");

                previousMax = ofGrade.stream().mapToInt(Quest::getExpReward).max().orElseThrow();
                previousGrade = grade;
            }
        }
    }

    /** 대역이 트랙마다 달라도 §2 표 전체의 바깥으로는 나가지 않는다 — 자릿수 실수를 잡는다. */
    @Test
    void 확장_시드의_EXP가_규칙서_전체_범위_안에_있다() {
        for (Quest quest : extendedSeededQuests()) {
            assertTrue(quest.getExpReward() >= MIN_EXP && quest.getExpReward() <= MAX_EXP,
                    "%s: EXP는 %d~%d여야 하는데 %d다"
                            .formatted(quest.getTitle(), MIN_EXP, MAX_EXP, quest.getExpReward()));
        }
    }

    private void assertExpWithin(List<Quest> quests, Map<QuestGrade, int[]> ranges) {
        for (Quest quest : quests) {
            int[] range = ranges.get(quest.getGrade());
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
     * <p>등급 분포의 출처는 V6 머리말이고 주기 분포는 V20 머리말이다 — V20가 37~42의 주기를 옮겼고,
     * 이미 적용된 V6는 체크섬 때문에 고칠 수 없어 머리말이 낡은 채 남아 있다.
     * 두 수치 모두 <b>비활성 2건을 포함한</b> id 1~42 전체 기준이다.
     */
    @Test
    void 시드_분포가_마이그레이션_머리말의_수치와_일치한다() {
        assertEquals(
                Map.of(QuestGrade.NORMAL, 19L, QuestGrade.RARE, 14L,
                        QuestGrade.EPIC, 7L, QuestGrade.LEGENDARY, 2L),
                baseSeededQuests().stream()
                        .collect(Collectors.groupingBy(Quest::getGrade, Collectors.counting())),
                "등급 분포가 V6 머리말과 다르다 — 시드를 고쳤다면 머리말 수치도 함께 갱신해야 한다");

        assertEquals(
                Map.of(QuestCadence.DAILY, 24L, QuestCadence.WEEKLY, 18L),
                baseSeededQuests().stream()
                        .collect(Collectors.groupingBy(Quest::getCadence, Collectors.counting())),
                "주기 분포가 V20 머리말과 다르다 — 주간 18건은 기존 12건에 재분류된 37~42를 더한 값이다");
    }

    /**
     * 확장분의 분포. V22은 슬롯 등급 결손(일간 SELF_REPORT의 EPIC·LEGENDARY 0건, 주간
     * SELF_REPORT의 NORMAL·EPIC 0건)을 메우려고 넣은 것이므로, <b>상위 등급이 많은 것이 의도</b>다.
     * 이 분포가 무너지면 결손이 되살아나 해당 슬롯에서 그 등급이 영영 안 나온다.
     */
    @Test
    void 확장_시드가_상위_등급_결손을_메우는_분포를_유지한다() {
        assertEquals(
                Map.of(QuestGrade.NORMAL, 4L, QuestGrade.RARE, 7L,
                        QuestGrade.EPIC, 9L, QuestGrade.LEGENDARY, 6L),
                extendedSeededQuests().stream()
                        .collect(Collectors.groupingBy(Quest::getGrade, Collectors.counting())),
                "등급 분포가 V22 의도와 다르다 — 상위 등급을 줄이면 슬롯 등급 결손이 되살아난다");

        assertEquals(
                Map.of(QuestCadence.DAILY, 13L, QuestCadence.WEEKLY, 13L),
                extendedSeededQuests().stream()
                        .collect(Collectors.groupingBy(Quest::getCadence, Collectors.counting())),
                "주기 분포가 V22과 다르다 — 두 트랙에 고르게 넣어 양쪽 결손을 함께 메웠다");
    }

    /**
     * V22 확장분은 전부 {@code SELF_REPORT}다. LOCATION 결손(일간 LOCATION이 RARE뿐)은
     * 좌표를 행에 고정하는 구조 때문에 분리했다고 머리말이 밝히고 있다.
     *
     * <p>여기에 LOCATION이 섞여 들어오면 그 결정이 조용히 뒤집힌 것이므로 드러나야 한다.
     */
    @Test
    void 확장_시드는_전부_직접_완료다() {
        for (Quest quest : extendedSeededQuests()) {
            assertFalse(quest.isLocationBased(),
                    quest.getTitle() + ": V22은 SELF_REPORT만 넣기로 했다 — "
                            + "LOCATION 결손은 반경 확대·지역 분산 중 방향이 정해진 뒤 별도 마이그레이션이다");
        }
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
