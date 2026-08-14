package com.lifequest.quest.domain;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.lifequest.quest.repository.QuestRepository;
import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.LongStream;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

/**
 * 시드 퀘스트 카탈로그가 업무 규칙의 불변식을 지키는지 검증한다.
 *
 * <p>검사는 두 갈래다. <b>id가 계약인 구간</b>(V6의 1~42는 업적이 참조 · V22의 43~68 · V33의
 * 69~105)은 번호로 재고, <b>V34 이후의 전국 시드</b>는 명시 id를 쓰지 않으므로 좌표와 장소로
 * 잰다({@link #allCatalogQuests()}).
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

    /** V22 확장분(SELF_REPORT)의 마지막 id. */
    private static final long EXTENDED_SEED_LAST_ID = 68L;

    /** V33 지역·템플릿 LOCATION 시드의 첫 id. 추가는 계속 뒤에 붙는다(V6 머리말). */
    private static final long LOCATION_SEED_FIRST_ID = 69L;

    /**
     * <b>명시 id를 쓰는 시드의 마지막 번호.</b> V34(전국 확장)부터는 id를 적지 않는다.
     *
     * <p>주간 AI 퀘스트가 개인 전용 행을 같은 {@code quests} 테이블에 AUTO_INCREMENT로 넣기
     * 때문이다({@code Quest.createPrivateAiWeekly}). AI 추천을 받은 적 있는 DB는 id가 이미
     * 100번대를 넘어서 있어, 거기에 명시 id 시드를 적용하면 duplicate key로 Flyway가 죽는다.
     * CI와 H2는 매번 새 DB라 통과하므로 <b>테스트로는 드러나지 않는 종류</b>다.
     *
     * <p>그래서 이 아래의 검사는 두 갈래다 — id가 계약인 구간(업적이 참조하는 1~42 등)은
     * 번호로 재고, 그 밖은 <b>좌표와 장소</b>로 잰다. 배정이 실제로 보는 것도 좌표다.
     */
    private static final long LAST_SEED_ID = 105L;

    /**
     * 배정이 후보를 좁히는 거리(m). {@code QuestAssignmentCreator}와 같은 값이며 트랙마다 다르다.
     * 시드가 이 반경을 전제로 짜였으므로 여기서도 같은 기준으로 재야 실제 배정과 같은 것을 본다.
     */
    private static final double DAILY_RADIUS_M = 15_000;
    private static final double WEEKLY_RADIUS_M = 50_000;

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

    /** 일간 트랙의 슬롯 수. {@code QuestAssignmentCreator.DAILY_SLOTS}와 같은 값이다. */
    private static final int DAILY_SLOT_COUNT = 3;

    /**
     * 시드가 덮기로 한 도시와 그 중심 좌표. V33의 6개(서울·5대 광역시)에 V34의 29개를 더한 값이다.
     *
     * <p>목록으로 두는 이유는 <b>커버리지가 데이터의 성질이 아니라 약속</b>이기 때문이다. 시드를
     * 늘리거나 줄일 때 "어느 도시를 덮기로 했는가"가 여기 남아 있지 않으면, 한 도시가 통째로
     * 빠져도 전체 건수만 보고는 드러나지 않는다 — 그 지역 사용자에게만 보이는 결손이 된다.
     */
    /**
     * {@code QuestLocationTargetingTests}가 "주변에 시드가 없는 사용자"를 세울 때 쓰는 좌표(완도).
     *
     * <p>그 테스트는 좌표가 아니라 <b>조건</b>을 필요로 하는데, 조건을 깨는 것은 이 파일이
     * 지키는 카탈로그 쪽이다. 실제로 V34가 제주를 덮으면서 제주를 쓰던 그 테스트 세 건이
     * 함께 깨졌고, 원인이 시드 확장이라는 것은 전체 테스트를 돌린 뒤에야 드러났다.
     * 여기서 먼저 잰다 — 카탈로그를 고친 사람이 카탈로그 테스트를 돌리면 걸린다.
     */
    private static final double[] NO_SEED_SPOT = {34.3110, 126.7550};

    private static final Map<String, double[]> CITIES = Map.ofEntries(
            Map.entry("서울", new double[] {37.5665, 126.9780}),
            Map.entry("부산", new double[] {35.1796, 129.0756}),
            Map.entry("대구", new double[] {35.8714, 128.6014}),
            Map.entry("인천", new double[] {37.4563, 126.7052}),
            Map.entry("대전", new double[] {36.3504, 127.3845}),
            Map.entry("광주", new double[] {35.1595, 126.8526}),
            Map.entry("수원", new double[] {37.2636, 127.0286}),
            Map.entry("성남", new double[] {37.4200, 127.1265}),
            Map.entry("고양", new double[] {37.6584, 126.8320}),
            Map.entry("용인", new double[] {37.2411, 127.1776}),
            Map.entry("부천", new double[] {37.5035, 126.7660}),
            Map.entry("안산", new double[] {37.3219, 126.8309}),
            Map.entry("남양주", new double[] {37.6360, 127.2165}),
            Map.entry("평택", new double[] {36.9921, 127.1129}),
            Map.entry("청주", new double[] {36.6424, 127.4890}),
            Map.entry("충주", new double[] {36.9910, 127.9260}),
            Map.entry("천안", new double[] {36.8151, 127.1139}),
            Map.entry("세종", new double[] {36.4800, 127.2890}),
            Map.entry("전주", new double[] {35.8242, 127.1480}),
            Map.entry("군산", new double[] {35.9676, 126.7368}),
            Map.entry("여수", new double[] {34.7604, 127.6622}),
            Map.entry("순천", new double[] {34.9507, 127.4872}),
            Map.entry("목포", new double[] {34.8118, 126.3922}),
            Map.entry("울산", new double[] {35.5384, 129.3114}),
            Map.entry("창원", new double[] {35.2280, 128.6811}),
            Map.entry("김해", new double[] {35.2285, 128.8894}),
            Map.entry("진주", new double[] {35.1800, 128.1076}),
            Map.entry("포항", new double[] {36.0190, 129.3435}),
            Map.entry("경주", new double[] {35.8562, 129.2247}),
            Map.entry("안동", new double[] {36.5684, 128.7294}),
            Map.entry("춘천", new double[] {37.8813, 127.7300}),
            Map.entry("원주", new double[] {37.3422, 127.9202}),
            Map.entry("강릉", new double[] {37.7519, 128.8761}),
            Map.entry("제주", new double[] {33.4996, 126.5312}),
            Map.entry("서귀포", new double[] {33.2541, 126.5601}));

    @Autowired
    private QuestRepository questRepository;

    /**
     * 공용 카탈로그 전체(AI 개인 퀘스트 제외).
     *
     * <p>id 범위 대신 이것을 쓰는 검사가 있다. V34부터 시드가 명시 id를 쓰지 않으므로
     * 번호로는 그 행들을 집을 수 없고, 애초에 <b>좌표·타입 불변식은 id와 무관</b>하다.
     * 개인 전용 AI 퀘스트는 카탈로그가 아니므로 {@code ownerUserId}로 제외한다.
     */
    private List<Quest> allCatalogQuests() {
        return questRepository.findAll().stream()
                .filter(quest -> quest.getOwnerUserId() == null)
                .toList();
    }

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
                LongStream.rangeClosed(BASE_SEED_LAST_ID + 1, EXTENDED_SEED_LAST_ID).boxed().toList());
    }

    /** V33 지역·템플릿 LOCATION 시드({@link #LOCATION_SEED_FIRST_ID}~{@link #LAST_SEED_ID}). */
    private List<Quest> locationSeededQuests() {
        return questRepository.findAllById(
                LongStream.rangeClosed(LOCATION_SEED_FIRST_ID, LAST_SEED_ID).boxed().toList());
    }

    @Test
    void 시드_퀘스트가_id_누락_없이_전부_적재된다() {
        assertEquals(LAST_SEED_ID - FIRST_SEED_ID + 1, seededQuests().size(),
                "id 1~%d가 모두 있어야 한다 — 1~42는 업적의 target_quest_id가 참조하고, "
                        .formatted(LAST_SEED_ID)
                        + "43~%d은 슬롯 등급 결손을(V22), %d~%d은 지역·템플릿 결손을(V33) 메운다. "
                                .formatted(EXTENDED_SEED_LAST_ID, LOCATION_SEED_FIRST_ID, LAST_SEED_ID)
                        + "V34 이후는 명시 id를 쓰지 않으므로 이 검사의 대상이 아니다");
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
        List<Quest> seeded = allCatalogQuests();

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

    /**
     * V33은 전부 LOCATION이다. 지역·템플릿 결손을 메우려고 넣은 것이므로 SELF_REPORT가 섞이면
     * 그 목적이 조용히 흐려진 것이다.
     */
    @Test
    void 지역_시드는_전부_위치_인증이다() {
        for (Quest quest : locationSeededQuests()) {
            assertTrue(quest.isLocationBased(),
                    quest.getTitle() + ": V33은 LOCATION만 넣기로 했다 — "
                            + "SELF_REPORT 결손은 V22이 이미 메웠다");
        }
    }

    /**
     * <b>도시마다 등급이 갖춰져 있어야 한다.</b> 배정이 사용자 주변으로 후보를 좁히므로
     * (V32·V33), 좁힌 뒤의 등급 분포를 정하는 것은 카탈로그 전체가 아니라 그 도시의 구성이다.
     * 한 도시에 한 등급뿐이면 그 지역 사용자의 슬롯 A는 매번 같은 등급이 된다 — 카탈로그 전체로
     * 세면 골고루 보이므로 전체 분포만 재는 검사로는 이 결손이 드러나지 않는다.
     *
     * <p>도시는 좌표로 묶는다. 시드에 지역 컬럼이 없고, 있다 해도 판정에 쓰이는 것은 좌표라
     * 그쪽을 기준으로 재야 실제 배정과 같은 것을 본다.
     */
    @Test
    void 도시마다_일간_주간_등급이_고루_갖춰져_있다() {
        List<Quest> located = allCatalogQuests().stream()
                .filter(Quest::isLocationBased)
                .filter(quest -> !quest.isLocationTemplate())
                .toList();

        for (Map.Entry<String, double[]> city : CITIES.entrySet()) {
            for (QuestCadence cadence : QuestCadence.values()) {
                // 반경이 트랙마다 다르므로 도시로 좁히는 것도 트랙 안에서 해야 한다 —
                // 바깥에서 한 번 좁혀 두면 두 트랙이 같은 반경을 쓰게 된다
                double radiusM = cadence == QuestCadence.WEEKLY ? WEEKLY_RADIUS_M : DAILY_RADIUS_M;
                long grades = located.stream()
                        .filter(quest -> quest.getCadence() == cadence)
                        .filter(quest -> withinCity(quest, city.getValue(), radiusM))
                        .map(Quest::getGrade)
                        .distinct()
                        .count();

                assertTrue(grades >= 2,
                        "%s의 %s LOCATION 등급이 %d종뿐이다 — 그 지역 사용자의 슬롯 A가 한 등급에 묶인다"
                                .formatted(city.getKey(), cadence, grades));
            }
        }
    }

    /**
     * 템플릿은 좌표를 배정 시점에 받는다. 그래도 행에는 좌표가 있어야 하고
     * ({@code ck_quests_location_verifiable}), 그 자리표가 시드된 도시 근처면 안 된다.
     *
     * <p>자리표가 서울에 있으면, override가 빠지는 버그가 생겨도 서울 사용자에게는 정상으로
     * 보인다 — 결함이 일부 사용자에게만 드러나면 재현이 어렵고 원인도 가려진다.
     */
    @Test
    void 템플릿_자리표_좌표는_어느_도시에서도_멀다() {
        List<Quest> templates = allCatalogQuests().stream()
                .filter(Quest::isLocationTemplate)
                .toList();

        assertFalse(templates.isEmpty(),
                "템플릿이 없으면 시드된 도시 밖 사용자는 위치 퀘스트를 받지 못한다");

        List<Quest> real = allCatalogQuests().stream()
                .filter(Quest::isLocationBased)
                .filter(quest -> !quest.isLocationTemplate())
                .toList();

        for (Quest template : templates) {
            assertTrue(template.isLocationBased(),
                    template.getTitle() + ": 템플릿인데 LOCATION이 아니다");

            for (Quest place : real) {
                double distance = meters(
                        template.getLatitude().doubleValue(), template.getLongitude().doubleValue(),
                        place.getLatitude().doubleValue(), place.getLongitude().doubleValue());
                assertTrue(distance > WEEKLY_RADIUS_M,
                        "%s의 자리표가 %s에서 %.0fkm뿐이다 — 판정 반경(%.0fkm) 안이라 override가 빠져도 "
                                .formatted(template.getTitle(), place.getPlaceName(),
                                        distance / 1000, WEEKLY_RADIUS_M / 1000)
                                + "그 지역 사용자에게는 정상으로 보인다");
            }
        }
    }

    /**
     * 템플릿 경로를 검증할 수 있는 <b>빈 지점이 남아 있어야 한다.</b>
     *
     * <p>카탈로그가 국토를 촘촘히 덮을수록 "주변에 시드가 없는 사용자"를 세울 곳이 사라진다.
     * 그 사용자가 없어지면 템플릿 배정·override 좌표·완료 판정을 재는 경로가 통째로 검증 밖으로
     * 나가는데, 기능이 죽은 것이 아니라 <b>재는 방법이 없어진 것</b>이라 조용하다.
     *
     * <p>시드를 더 넣어 이 테스트가 실패하면 둘 중 하나를 한다 — 더 먼 지점을 찾아
     * {@link #NO_SEED_SPOT}과 {@code QuestLocationTargetingTests}를 함께 옮기거나,
     * 그 지역을 덮지 않기로 한다.
     */
    @Test
    void 템플릿_경로를_잴_수_있는_빈_지점이_남아_있다() {
        List<Quest> real = allCatalogQuests().stream()
                .filter(Quest::isLocationBased)
                .filter(quest -> !quest.isLocationTemplate())
                .toList();

        Quest nearest = real.stream()
                .min((a, b) -> Double.compare(distanceFromNoSeedSpot(a), distanceFromNoSeedSpot(b)))
                .orElseThrow();
        double distance = distanceFromNoSeedSpot(nearest);

        assertTrue(distance > WEEKLY_RADIUS_M,
                "빈 지점으로 쓰던 좌표에서 %s까지 %.0fkm뿐이다 — 판정 반경(%.0fkm) 안이라 "
                        .formatted(nearest.getPlaceName(), distance / 1000, WEEKLY_RADIUS_M / 1000)
                        + "그 사용자에게 실재 장소가 배정되고, 템플릿 경로를 재던 테스트가 함께 깨진다");
    }

    private static double distanceFromNoSeedSpot(Quest quest) {
        return meters(NO_SEED_SPOT[0], NO_SEED_SPOT[1],
                quest.getLatitude().doubleValue(), quest.getLongitude().doubleValue());
    }

    /**
     * <b>V34 이후의 시드 마이그레이션은 id를 적지 않아야 한다.</b>
     *
     * <p>주간 AI 퀘스트가 개인 전용 행을 같은 {@code quests} 테이블에 AUTO_INCREMENT로 넣으므로
     * ({@code Quest.createPrivateAiWeekly}), AI 추천을 받은 적 있는 DB는 id가 이미 전진해 있다.
     * 거기에 명시 id 시드를 적용하면 duplicate key로 Flyway가 죽고, 그 사람의 앱은 부팅되지 않는다.
     *
     * <p><b>이 결함은 데이터가 아니라 SQL 텍스트의 성질이라 적재 결과로는 잴 수 없다.</b> CI와
     * H2는 매번 새 DB라 명시 id가 그대로 들어가 전부 통과한다 — 그래서 파일을 직접 읽는다.
     *
     * <p>V33 이하는 이미 팀원 DB에 적용돼 checksum이 고정되어 있어 고칠 수 없다. 규칙은
     * <b>앞으로 추가되는 것</b>에만 적용한다.
     */
    @Test
    void 전국_시드_이후의_마이그레이션은_퀘스트_id를_명시하지_않는다() throws Exception {
        Path migrations = Path.of("src/main/resources/db/migration");
        assertTrue(Files.isDirectory(migrations), "마이그레이션 디렉터리를 찾지 못했다: " + migrations);

        Pattern versioned = Pattern.compile("^V(\\d+)__.*\\.sql$");
        try (Stream<Path> files = Files.list(migrations)) {
            for (Path file : files.sorted().toList()) {
                Matcher matcher = versioned.matcher(file.getFileName().toString());
                if (!matcher.matches() || Integer.parseInt(matcher.group(1)) < 34) {
                    continue;
                }
                String sql = Files.readString(file);
                if (!sql.contains("INSERT INTO quests")) {
                    continue;
                }
                assertFalse(sql.matches("(?s).*INSERT INTO quests\\s*\\(\\s*id\\s*,.*"),
                        file.getFileName() + ": INSERT INTO quests에 id를 명시했다 — "
                                + "AI 퀘스트가 같은 테이블의 AUTO_INCREMENT를 쓰므로 "
                                + "그 기능을 사용한 DB에서는 duplicate key로 부팅이 실패한다");
            }
        }
    }

    private static boolean withinCity(Quest quest, double[] center, double radiusM) {
        return meters(center[0], center[1],
                quest.getLatitude().doubleValue(), quest.getLongitude().doubleValue()) <= radiusM;
    }

    private static double meters(double lat1, double lon1, double lat2, double lon2) {
        double earthRadiusM = 6_371_000;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.pow(Math.sin(dLat / 2), 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.pow(Math.sin(dLon / 2), 2);
        return earthRadiusM * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    @Test
    void LOCATION_퀘스트는_전부_GPS로_판정할_수_있다() {
        List<Quest> located = allCatalogQuests().stream().filter(Quest::isLocationBased).toList();
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

        for (Quest quest : allCatalogQuests().stream().filter(Quest::isLocationBased).toList()) {
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
        for (Quest quest : allCatalogQuests().stream().filter(q -> !q.isLocationBased()).toList()) {
            assertNull(quest.getLatitude(), quest.getTitle() + ": 직접 완료인데 위도가 있다");
            assertNull(quest.getLongitude(), quest.getTitle() + ": 직접 완료인데 경도가 있다");
            assertNull(quest.getRadiusM(), quest.getTitle() + ": 직접 완료인데 반경이 있다");
            assertNull(quest.getPlaceName(), quest.getTitle() + ": 직접 완료인데 장소명이 있다");
        }
    }

    /**
     * <b>이동 없이 끝낼 수 있는 후보가 슬롯을 채우고도 남아야 한다.</b>
     *
     * <p>비율이 아니라 절대 건수를 재는 이유는 배정이 슬롯 단위이기 때문이다. 일간 슬롯은
     * A={@code {LOCATION}} · B={@code {SELF_REPORT}} · C={@code {전부}} 구성이고
     * ({@code QuestAssignmentCreator.DAILY_SLOTS}), 슬롯 A는 LOCATION만 가져가므로 B 차례에는
     * SELF_REPORT 후보가 그대로 남아 있다. <b>배정 3칸 중 한 칸은 구조적으로 이동이 필요 없고</b>,
     * 카탈로그에서 LOCATION이 늘어도 그 보장은 흔들리지 않는다.
     *
     * <p>보장이 깨지는 경로는 완화 ②(완료 타입 제약 해제, {@code QuestSlotDrawer})뿐이며 발동
     * 조건은 <b>두 풀 모두에 SELF_REPORT가 없는 것</b>이다. 배정이 위치로 좁히는 것은 LOCATION
     * 후보뿐이므로({@code QuestAssignmentCreator#createForTrack}) SELF_REPORT는 어느 지역
     * 사용자에게나 전량 남는다 — 지역 시드를 늘려도 이 조건에 가까워지지 않는다.
     *
     * <p>배수 2는 슬롯 B와 C가 <b>둘 다</b> SELF_REPORT를 가져가는 경우와 직전 주기 제외를 함께
     * 흡수한다.
     *
     * <p>이전 기준은 "일간 직접 완료가 과반"이었다. 그것이 막으려던 상황은 <i>하루치가 통째로
     * 잠기는 것</i>인데 슬롯 B가 있는 한 성립하지 않으며, 대신 지역 확장의 상한이 되어 있었다
     * — 실제 필요치의 다섯 배를 요구했다.
     */
    @Test
    void 일간_배정에는_이동_없이_끝낼_수_있는_후보가_남는다() {
        long selfReport = allCatalogQuests().stream()
                .filter(quest -> quest.getCadence() == QuestCadence.DAILY)
                .filter(quest -> !quest.isLocationBased())
                .count();

        assertTrue(selfReport >= DAILY_SLOT_COUNT * 2,
                "일간 직접 완료 후보가 %d건뿐이다 — 슬롯 B가 완화 ②로 넘어가면 배정 %d칸이 "
                        .formatted(selfReport, DAILY_SLOT_COUNT)
                        + "전부 이동을 요구할 수 있다");
    }
}
