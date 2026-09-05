package com.lifequest.collection;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.context.ActiveProfiles;

/**
 * 도감 카탈로그가 수집 범위 규칙(docs/05-business-rules.md §6-1)대로 서 있는지 본다.
 *
 * <p>연결이 빠졌을 때 나는 증상이 오류가 아니라서 필요한 검사다 — 퀘스트는 완료되고 EXP도
 * 들어오는데 수집만 일어나지 않아 "연결이 없다"는 정상 동작으로 지나간다. V33·V34가 전국
 * 206곳을 넣으면서 {@code lifedex_item_id} 자리를 NULL로 둔 것이 오래 드러나지 않은 이유다.
 *
 * <p>다른 테스트가 만드는 픽스처 퀘스트에 흔들리지 않도록 <b>도감 쪽에서</b> 센다. 픽스처는
 * {@code lifedex_items}에 행을 넣지 않으므로 여기 수치는 시드만 반영한다.
 */
@SpringBootTest
@ActiveProfiles("test")
class LifedexCatalogContractTests {

    /**
     * 시드가 싣는 도감 항목 수 = 장소가 고정된 위치 퀘스트 전량(V26 15 + V37 206).
     *
     * <p>위치 퀘스트를 새로 넣으면 도감 항목도 함께 넣고 이 수를 올린다. 여기서 걸리는 것이
     * 곧 "다녀왔는데 도감에 아무것도 남지 않는" 상태이므로, 숫자를 맞추는 대신 항목을 빠뜨리지
     * 않았는지를 먼저 본다.
     */
    private static final long SEEDED_ITEM_COUNT = 221L;

    @Autowired
    private JdbcClient jdbcClient;

    @Test
    void catalogCoversEveryRealPlaceLocationQuest() {
        assertThat(count("SELECT COUNT(*) FROM lifedex_items"))
                .as("도감 항목 수 — 장소가 고정된 위치 퀘스트와 같아야 한다")
                .isEqualTo(SEEDED_ITEM_COUNT);
    }

    @Test
    void everyItemIsLinkedBackFromTheQuestItCameFrom() {
        // 항목 id는 원본 퀘스트 id와 같다(§6-1). 그래서 연결 여부는 같은 id의 퀘스트가
        // 자신을 가리키는지로 확인된다.
        Long orphaned = count("""
                SELECT COUNT(*) FROM lifedex_items li
                WHERE NOT EXISTS (
                    SELECT 1 FROM quests q WHERE q.id = li.id AND q.lifedex_item_id = li.id)
                """);

        assertThat(orphaned).as("가리키는 퀘스트가 없는 도감 항목").isZero();
    }

    @Test
    void noQuestPointsAtSomeoneElsesItem() {
        Long mismatched = count("""
                SELECT COUNT(*) FROM quests
                WHERE lifedex_item_id IS NOT NULL AND lifedex_item_id <> id
                """);

        assertThat(mismatched).isZero();
    }

    /**
     * 스키마는 {@code icon_key}가 비어도 받는다(비면 앱이 카테고리 모티프로 물러난다 —
     * docs/09-design-system.md §2). 그래도 <b>시드는 전부 채운다</b>: 물러남은 아트가 아직
     * 없을 때를 위한 것이지, 시드가 분류를 생략해도 된다는 뜻이 아니다.
     */
    @Test
    void everyItemCarriesAnIconKey() {
        Long missing = count("SELECT COUNT(*) FROM lifedex_items WHERE icon_key IS NULL");

        assertThat(missing).as("아이콘 키가 없는 도감 항목").isZero();
    }

    /**
     * 키 어휘의 정본은 DB가 아니라 앱의 {@code LqLifedexIcons}다. 아래 목록은 그 사본이
     * 아니라 <b>어긋남 탐지기</b>다 — 앱이 모르는 키를 시드가 넣어도 화면은 죽지 않고
     * 카테고리 모티프로 물러나므로(같은 문서), 오타 하나가 눈으로 보기 전까지 지나간다.
     * 앱에 유형이 새로 등록되면 여기도 함께 늘린다.
     */
    @Test
    void everyIconKeyIsOneTheAppKnows() {
        List<String> known = List.of(
                "cafe", "park_city", "park_forest", "garden", "trail", "waterside", "beach",
                "mountain", "library", "museum", "gallery", "market", "street", "hanok",
                "palace", "heritage", "tower");

        List<String> unknown = jdbcClient
                .sql("SELECT DISTINCT icon_key FROM lifedex_items WHERE icon_key IS NOT NULL")
                .query(String.class)
                .list()
                .stream()
                .filter(key -> !known.contains(key))
                .toList();

        assertThat(unknown).as("앱이 모르는 아이콘 키").isEmpty();
    }

    /**
     * 초기 서울 15개 항목은 id와 이름을 바꾸지 않는다. 시연 시더가 좌표로 고른 퀘스트의 id가
     * 그대로 도감 항목 id가 되므로, 항목을 재편하면 시연 영상의 도장 장면이 조용히 다른
     * 장소로 바뀐다.
     */
    @Test
    void initialSeoulItemsKeepTheirIdAndName() {
        assertThat(nameOf(21L)).isEqualTo("청계천");
        assertThat(nameOf(23L)).isEqualTo("반포한강공원");
        assertThat(nameOf(28L)).isEqualTo("경복궁");
        assertThat(nameOf(42L)).isEqualTo("서울식물원");
    }

    private Long count(String sql) {
        return jdbcClient.sql(sql).query(Long.class).single();
    }

    private String nameOf(Long itemId) {
        return jdbcClient.sql("SELECT name FROM lifedex_items WHERE id = :id")
                .param("id", itemId)
                .query(String.class)
                .single();
    }
}
