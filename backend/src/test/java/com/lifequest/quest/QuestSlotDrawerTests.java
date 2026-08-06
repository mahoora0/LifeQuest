package com.lifequest.quest;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

import com.lifequest.quest.domain.CompletionType;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.domain.QuestCreator;
import com.lifequest.quest.domain.QuestGrade;
import com.lifequest.quest.service.QuestSlotDrawer;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.Set;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Timeout;

/**
 * 슬롯 추출의 순수 계층 검증(docs/05-business-rules.md §1·§1-B).
 *
 * <p>DB를 끼지 않으므로 반복 검증이 가능하다. 확률 추출과 완화 순서는 틀려도 조용하다 —
 * 예외도 로그도 없이 슬롯이 비거나 어제 것이 다시 나올 뿐이라, 반복 실행으로만 드러난다.
 *
 * <p><b>슬롯별로 잰다.</b> 슬롯 A가 타입 제약을 받으므로 세 슬롯을 합치면 확률표
 * {@code 55/30/12/3}이 나오지 않는 것이 정상이다. 분포를 재는 시험은 슬롯 하나만 넘긴다.
 *
 * <p>{@code @Timeout}은 장식이 아니다. 완화 경로는 {@code while} 루프 안에서 제약을 풀어가므로,
 * 종료 조건을 빠뜨리면 실패가 아니라 정지로 나타난다.
 */
@Timeout(value = 60, unit = TimeUnit.SECONDS)
class QuestSlotDrawerTests {

    private static final Set<CompletionType> SLOT_LOCATION = Set.of(CompletionType.LOCATION);
    private static final Set<CompletionType> SLOT_SELF_REPORT = Set.of(CompletionType.SELF_REPORT);
    /** 슬롯 C — 타입 제한 없이 잔여에서 고른다. */
    private static final Set<CompletionType> SLOT_ANY =
        Set.of(CompletionType.LOCATION, CompletionType.SELF_REPORT);

    private final QuestSlotDrawer drawer = new QuestSlotDrawer();

    // ------------------------------------------------------------------
    // #1 슬롯 수
    // ------------------------------------------------------------------

    @Test
    void 슬롯_수만큼_배정한다() {
        List<Quest> drawn = drawer.questDrawer(
            List.of(SLOT_LOCATION, SLOT_SELF_REPORT, SLOT_ANY),
            weeklyPool(), noExclusion(), new Random(1L));

        assertThat(drawn).hasSize(3);
    }

    @Test
    void 풀이_슬롯보다_적으면_그만큼만_배정한다() {
        List<Quest> pool = mutable(selfReport(QuestGrade.NORMAL), selfReport(QuestGrade.RARE));

        List<Quest> drawn = drawer.questDrawer(
            List.of(SLOT_ANY, SLOT_ANY, SLOT_ANY), pool, noExclusion(), new Random(1L));

        assertThat(drawn).hasSize(2);
    }

    @Test
    void 같은_퀘스트를_두_슬롯에_중복_배정하지_않는다() {
        for (int seed = 0; seed < 200; seed++) {
            List<Quest> drawn = drawer.questDrawer(
                List.of(SLOT_LOCATION, SLOT_SELF_REPORT, SLOT_ANY),
                weeklyPool(), noExclusion(), new Random(seed));

            assertThat(drawn).doesNotHaveDuplicates();
        }
    }

    // ------------------------------------------------------------------
    // #2 타입 보장
    // ------------------------------------------------------------------

    @Test
    void 두_완료_타입이_각각_하나_이상_배정된다() {
        for (int seed = 0; seed < 200; seed++) {
            List<Quest> drawn = drawer.questDrawer(
                List.of(SLOT_LOCATION, SLOT_SELF_REPORT, SLOT_ANY),
                weeklyPool(), noExclusion(), new Random(seed));

            assertThat(drawn).anyMatch(Quest::isLocationBased);
            assertThat(drawn).anyMatch(quest -> !quest.isLocationBased());
        }
    }

    @Test
    void 슬롯이_정한_타입_밖의_퀘스트는_그_슬롯에_들어가지_않는다() {
        for (int seed = 0; seed < 200; seed++) {
            List<Quest> drawn = drawer.questDrawer(
                List.of(SLOT_LOCATION), weeklyPool(), noExclusion(), new Random(seed));

            assertThat(drawn).hasSize(1);
            assertThat(drawn.get(0).isLocationBased()).isTrue();
        }
    }

    // ------------------------------------------------------------------
    // #3 등급 정규화 — 풀에 없는 등급은 확률이 0이 되고 나머지가 비례 재배분된다
    // ------------------------------------------------------------------

    @Test
    void 주간_LOCATION_슬롯에는_NORMAL이_한_번도_나오지_않는다() {
        for (int seed = 0; seed < 1_000; seed++) {
            List<Quest> drawn = drawer.questDrawer(
                List.of(SLOT_LOCATION), weeklyPool(), noExclusion(), new Random(seed));

            assertThat(drawn.get(0).getGrade()).isNotEqualTo(QuestGrade.NORMAL);
        }
    }

    // ------------------------------------------------------------------
    // #4 확률 분포 — 고정 시드로 재고 슬롯별 기대치와 대조한다
    // ------------------------------------------------------------------

    @Test
    void 주간_LOCATION_슬롯의_등급_분포가_정규화_결과와_일치한다() {
        // 풀에 NORMAL이 없어 55%가 갈 곳을 잃고 30/12/3에 비례 배분된다 → 66.7 / 26.7 / 6.7
        Map<QuestGrade, Integer> counts = drawGradeHistogram(SLOT_LOCATION, 10_000);

        assertThat(share(counts, QuestGrade.NORMAL)).isZero();
        assertThat(share(counts, QuestGrade.RARE)).isCloseTo(0.667, within(0.02));
        assertThat(share(counts, QuestGrade.EPIC)).isCloseTo(0.267, within(0.02));
        assertThat(share(counts, QuestGrade.LEGENDARY)).isCloseTo(0.067, within(0.015));
    }

    @Test
    void 주간_SELF_REPORT_슬롯의_등급_분포는_확률표_그대로다() {
        // 네 등급이 모두 있으므로 재배분이 일어나지 않는다
        Map<QuestGrade, Integer> counts = drawGradeHistogram(SLOT_SELF_REPORT, 10_000);

        assertThat(share(counts, QuestGrade.NORMAL)).isCloseTo(0.55, within(0.02));
        assertThat(share(counts, QuestGrade.RARE)).isCloseTo(0.30, within(0.02));
        assertThat(share(counts, QuestGrade.EPIC)).isCloseTo(0.12, within(0.015));
        assertThat(share(counts, QuestGrade.LEGENDARY)).isCloseTo(0.03, within(0.01));
    }

    @Test
    void 같은_등급_안에서는_후보를_균등하게_고른다() {
        // 크기 편향의 반대 방향 확인 — 등급이 정해진 뒤에는 후보 수가 확률에 영향을 주면 안 된다.
        // 주간 LOCATION의 RARE는 5건이므로 각 20% 부근이어야 한다.
        Random random = new Random(20_260_806L);
        Map<String, Integer> byTitle = new java.util.HashMap<>();
        int rareDraws = 0;

        for (int i = 0; i < 20_000; i++) {
            List<Quest> drawn = drawer.questDrawer(
                List.of(SLOT_LOCATION), weeklyPool(), noExclusion(), random);
            Quest quest = drawn.get(0);
            if (quest.getGrade() == QuestGrade.RARE) {
                byTitle.merge(quest.getTitle(), 1, Integer::sum);
                rareDraws++;
            }
        }

        assertThat(byTitle).hasSize(5);
        for (int count : byTitle.values()) {
            assertThat((double) count / rareDraws).isCloseTo(0.20, within(0.03));
        }
    }

    // ------------------------------------------------------------------
    // #5 직전 주기 제외 — 어제(지난주) 배정분은 대안이 있는 한 다시 나오지 않는다
    // ------------------------------------------------------------------

    @Test
    void 직전_주기_배정분은_풀에_대안이_있으면_다시_뽑히지_않는다() {
        for (int seed = 0; seed < 200; seed++) {
            List<Quest> pool = mutable(
                selfReport(QuestGrade.NORMAL), selfReport(QuestGrade.RARE), selfReport(QuestGrade.EPIC));
            Quest lastPeriod = selfReport(QuestGrade.NORMAL);

            List<Quest> drawn = drawer.questDrawer(
                List.of(SLOT_SELF_REPORT), pool, mutable(lastPeriod), new Random(seed));

            assertThat(drawn).doesNotContain(lastPeriod);
        }
    }

    @Test
    void 제외_집합은_슬롯_타입이_다르면_애초에_후보가_아니다() {
        for (int seed = 0; seed < 200; seed++) {
            List<Quest> pool = weeklyPool();
            Quest lastPeriod = location(QuestGrade.RARE);

            List<Quest> drawn = drawer.questDrawer(
                List.of(SLOT_SELF_REPORT), pool, mutable(lastPeriod), new Random(seed));

            assertThat(drawn).doesNotContain(lastPeriod);
        }
    }

    // ------------------------------------------------------------------
    // #6 제외 해제 — 완화 1단계
    // ------------------------------------------------------------------

    @Test
    void 슬롯_타입_후보가_풀에_없으면_제외를_풀어_채운다() {
        Quest lastPeriod = location(QuestGrade.RARE);

        List<Quest> drawn = drawer.questDrawer(
            List.of(SLOT_LOCATION), mutable(), mutable(lastPeriod), new Random(1L));

        assertThat(drawn).containsExactly(lastPeriod);
    }

    // ------------------------------------------------------------------
    // #6-1 완화 순서 — 제외 해제(①)가 타입 제약 해제(②)보다 먼저다
    // ------------------------------------------------------------------

    @Test
    void 제외_해제로_채울_수_있으면_타입_제약_해제보다_먼저_쓴다() {
        // 풀에 SELF_REPORT는 남아 있다. "풀 전체가 비었나"로 완화를 판정하면 ①을 건너뛰고
        // ②가 먼저 발동해, 지난 주기의 LOCATION 대신 엉뚱한 타입이 슬롯에 들어간다.
        List<Quest> pool = mutable(selfReport(QuestGrade.NORMAL), selfReport(QuestGrade.EPIC));
        Quest lastPeriod = location(QuestGrade.RARE);

        List<Quest> drawn = drawer.questDrawer(
            List.of(SLOT_LOCATION), pool, mutable(lastPeriod), new Random(1L));

        assertThat(drawn).containsExactly(lastPeriod);
    }

    @Test
    void 두_풀_모두_슬롯_타입이_없으면_타입_제약을_풀어_채운다() {
        // 완화 ② — LOCATION이 어디에도 없으므로 타입 보장을 포기하고 슬롯을 채운다
        List<Quest> pool = mutable(selfReport(QuestGrade.NORMAL));

        List<Quest> drawn = drawer.questDrawer(
            List.of(SLOT_LOCATION), pool, noExclusion(), new Random(1L));

        assertThat(drawn).hasSize(1);
        assertThat(drawn.get(0).isLocationBased()).isFalse();
    }

    @Test
    void 타입_제약_해제는_슬롯마다_독립적으로_적용된다() {
        // 앞 슬롯이 완화를 썼다고 뒤 슬롯까지 포기하면 안 된다 — 완화는 그 슬롯에 한정된다
        List<Quest> pool = mutable(selfReport(QuestGrade.NORMAL), selfReport(QuestGrade.RARE));

        List<Quest> drawn = drawer.questDrawer(
            List.of(SLOT_LOCATION, SLOT_SELF_REPORT), pool, noExclusion(), new Random(1L));

        assertThat(drawn).hasSize(2);
    }

    @Test
    void 양쪽_풀이_모두_비면_남은_슬롯_없이_반환한다() {
        List<Quest> drawn = drawer.questDrawer(
            List.of(SLOT_LOCATION, SLOT_SELF_REPORT, SLOT_ANY),
            mutable(), noExclusion(), new Random(1L));

        assertThat(drawn).isEmpty();
    }

    // ------------------------------------------------------------------
    // 순수성 — 설계상 이 클래스는 난수만 주입받는 순수 함수다
    // ------------------------------------------------------------------

    @Test
    void 호출자가_넘긴_풀을_변형하지_않는다() {
        List<Quest> pool = weeklyPool();
        int before = pool.size();

        drawer.questDrawer(
            List.of(SLOT_LOCATION, SLOT_SELF_REPORT, SLOT_ANY), pool, noExclusion(), new Random(1L));

        assertThat(pool).hasSize(before);
    }

    @Test
    void 호출자가_넘긴_제외_집합도_변형하지_않는다() {
        // 제외 집합에서 실제로 뽑히는 상황(완화 ① 발동)이라야 관측된다 —
        // 빈 리스트를 넘기면 이 경로를 한 번도 지나지 않아 통과해 버린다.
        List<Quest> pool = mutable(selfReport(QuestGrade.NORMAL));
        List<Quest> lastPeriod = mutable(location(QuestGrade.RARE));
        int before = lastPeriod.size();

        List<Quest> drawn = drawer.questDrawer(
            List.of(SLOT_LOCATION), pool, lastPeriod, new Random(1L));

        assertThat(drawn).hasSize(1);
        assertThat(lastPeriod).hasSize(before);
    }

    @Test
    void 같은_시드는_같은_결과를_낸다() {
        List<Quest> first = drawer.questDrawer(
            List.of(SLOT_LOCATION, SLOT_SELF_REPORT, SLOT_ANY),
            weeklyPool(), noExclusion(), new Random(42L));
        List<Quest> second = drawer.questDrawer(
            List.of(SLOT_LOCATION, SLOT_SELF_REPORT, SLOT_ANY),
            weeklyPool(), noExclusion(), new Random(42L));

        assertThat(titlesOf(first)).isEqualTo(titlesOf(second));
    }

    // ------------------------------------------------------------------
    // 픽스처 — 설계상 주간 활성 풀의 등급 구성을 그대로 옮긴 것
    // ------------------------------------------------------------------

    /** LOCATION 11건(N 0 / R 5 / E 5 / L 1) + SELF_REPORT 18건(N 4 / R 5 / E 5 / L 4). */
    private static List<Quest> weeklyPool() {
        List<Quest> pool = new ArrayList<>();
        addAll(pool, 5, QuestGrade.RARE, CompletionType.LOCATION);
        addAll(pool, 5, QuestGrade.EPIC, CompletionType.LOCATION);
        addAll(pool, 1, QuestGrade.LEGENDARY, CompletionType.LOCATION);
        addAll(pool, 4, QuestGrade.NORMAL, CompletionType.SELF_REPORT);
        addAll(pool, 5, QuestGrade.RARE, CompletionType.SELF_REPORT);
        addAll(pool, 5, QuestGrade.EPIC, CompletionType.SELF_REPORT);
        addAll(pool, 4, QuestGrade.LEGENDARY, CompletionType.SELF_REPORT);
        return pool;
    }

    private static void addAll(List<Quest> pool, int count, QuestGrade grade, CompletionType type) {
        for (int i = 0; i < count; i++) {
            String title = "%s-%s-%d".formatted(type.name(), grade.name(), i);
            pool.add(type == CompletionType.LOCATION ? location(grade, title) : selfReport(grade, title));
        }
    }

    private Map<QuestGrade, Integer> drawGradeHistogram(Set<CompletionType> slot, int trials) {
        Random random = new Random(20_260_806L);
        Map<QuestGrade, Integer> counts = new EnumMap<>(QuestGrade.class);
        for (int i = 0; i < trials; i++) {
            List<Quest> drawn = drawer.questDrawer(List.of(slot), weeklyPool(), noExclusion(), random);
            counts.merge(drawn.get(0).getGrade(), 1, Integer::sum);
        }
        return counts;
    }

    private static double share(Map<QuestGrade, Integer> counts, QuestGrade grade) {
        int total = counts.values().stream().mapToInt(Integer::intValue).sum();
        return (double) counts.getOrDefault(grade, 0) / total;
    }

    private static List<String> titlesOf(List<Quest> quests) {
        return quests.stream().map(Quest::getTitle).toList();
    }

    private static List<Quest> mutable(Quest... quests) {
        return new ArrayList<>(List.of(quests));
    }

    private static List<Quest> noExclusion() {
        return new ArrayList<>();
    }

    private static Quest location(QuestGrade grade) {
        return location(grade, "LOCATION-" + grade.name());
    }

    private static Quest location(QuestGrade grade, String title) {
        return new Quest(title, null, grade, QuestCadence.WEEKLY, CompletionType.LOCATION, 50,
            "테스트 장소", new BigDecimal("37.5665000"), new BigDecimal("126.9780000"), 100,
            null, QuestCreator.SYSTEM, true);
    }

    private static Quest selfReport(QuestGrade grade) {
        return selfReport(grade, "SELF_REPORT-" + grade.name());
    }

    private static Quest selfReport(QuestGrade grade, String title) {
        return new Quest(title, null, grade, QuestCadence.WEEKLY, CompletionType.SELF_REPORT, 50,
            null, null, null, null, null, QuestCreator.SYSTEM, true);
    }
}
