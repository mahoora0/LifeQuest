package com.lifequest.demo;

import static org.assertj.core.api.Assertions.assertThat;

import com.lifequest.growth.GrowthService;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.TestPropertySource;

/**
 * 데모 시더가 실제로 적재되는지 고정한다.
 *
 * <p><b>컴파일은 SQL을 검증하지 않는다.</b> 컬럼명 오타·제약 위반·순서 의존(인증 게시물이
 * 완료 이력을 참조하는 것 같은)은 전부 실행해야 드러나고, 그때는 이미 개발자가 앱을 띄운
 * 뒤다. 여기서 먼저 잡는다.
 *
 * <p><b>DB를 따로 쓴다.</b> 다른 테스트와 같은 인메모리 이름({@code lifequest})을 쓰면
 * {@code DB_CLOSE_DELAY=-1} 때문에 같은 JVM 안에서 공유되어, 시연용 사용자 12명이 남의
 * 테스트 조회에 섞인다.
 */
@SpringBootTest
@ActiveProfiles({"test", "demo"})
@TestPropertySource(properties =
    "spring.datasource.url=jdbc:h2:mem:demoseed;MODE=MySQL;DB_CLOSE_DELAY=-1;DATABASE_TO_LOWER=TRUE")
class DemoDataSeederTests {

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private DemoDataSeeder seeder;

    private int count(String table) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM " + table, Integer.class);
        return n == null ? 0 : n;
    }

    @Test
    void 시연용_사용자와_관계가_모두_적재된다() {
        assertThat(count("users")).as("시연 사용자 12명").isEqualTo(12);

        assertThat(jdbc.queryForObject(
            "SELECT COUNT(*) FROM users WHERE email = ?", Integer.class, DemoDataSeeder.DEMO_EMAIL))
            .as("로그인해서 둘러볼 주인공 계정이 있어야 한다")
            .isEqualTo(1);

        assertThat(count("friendships")).isPositive();
        assertThat(count("quest_groups")).isPositive();
        assertThat(count("group_members")).isPositive();
        assertThat(count("group_quests")).isPositive();
        assertThat(count("group_quest_participants")).isPositive();
        assertThat(count("group_chat_messages")).isPositive();
        assertThat(count("quest_completions")).isPositive();
        assertThat(count("quest_proof_posts")).isPositive();
        assertThat(count("quest_proof_votes")).isPositive();
        assertThat(count("quest_proof_comments")).isPositive();
        assertThat(count("notifications")).isPositive();
        assertThat(count("user_lifedex")).isPositive();
        assertThat(count("exp_logs")).isPositive();
    }

    /**
     * 레벨을 손으로 적지 않고 EXP에서 계산했는지 본다.
     *
     * <p>둘이 어긋나면 프로필의 레벨 표시와 다음 레벨까지의 진행률이 서로 다른 근거를 갖게 되고,
     * 그 어긋남은 데이터를 넣은 사람에게는 보이지 않는다.
     */
    @Test
    void 모든_사용자의_레벨이_EXP에서_계산된_값과_같다() {
        List<Map<String, Object>> rows = jdbc.queryForList(
            "SELECT nickname, total_exp, level FROM users");

        for (Map<String, Object> row : rows) {
            int totalExp = ((Number) row.get("total_exp")).intValue();
            int level = ((Number) row.get("level")).intValue();
            assertThat(level)
                .as("%s: EXP %d의 레벨은 %d여야 한다",
                    row.get("nickname"), totalExp, GrowthService.levelFor(totalExp))
                .isEqualTo(GrowthService.levelFor(totalExp));
        }
    }

    /**
     * 화면이 상태별 분기를 갖는 곳은 <b>상태가 둘 이상</b> 들어 있어야 한다.
     *
     * <p>한 상태만 넣으면 그 화면은 채워져 보이지만 분기는 여전히 검증되지 않는다 — 더미
     * 데이터를 넣는 목적이 "비어 보이지 않게"가 아니라 "각 경로를 눌러 볼 수 있게"이므로
     * 여기서 다양성 자체를 잰다.
     */
    @Test
    void 상태별_분기를_눌러_볼_수_있을_만큼_다양하다() {
        assertThat(jdbc.queryForList("SELECT DISTINCT status FROM friend_requests", String.class))
            .as("친구 요청은 수락·대기·거절이 모두 있어야 각 탭이 채워진다")
            .contains("PENDING", "ACCEPTED", "REJECTED");

        assertThat(jdbc.queryForList("SELECT DISTINCT status FROM group_members", String.class))
            .as("초대·가입신청·활동중이 모두 있어야 초대함·승인대기 화면이 산다")
            .contains("ACTIVE", "INVITED", "PENDING_APPROVAL");

        assertThat(jdbc.queryForList("SELECT DISTINCT status FROM group_quests", String.class))
            .as("예정·완료·취소가 모두 있어야 목록 필터가 검증된다")
            .contains("PUBLISHED", "COMPLETED", "CANCELLED");

        assertThat(jdbc.queryForList("SELECT DISTINCT status FROM quest_proof_posts", String.class))
            .as("투표중·검증됨·애매함이 모두 있어야 피드 탭이 갈린다")
            .contains("VOTING", "VERIFIED", "UNCLEAR");

        assertThat(jdbc.queryForList("SELECT DISTINCT visibility FROM quest_groups", String.class))
            .contains("PUBLIC", "PRIVATE");

        assertThat(jdbc.queryForObject(
            "SELECT COUNT(*) FROM notifications WHERE read_at IS NULL", Integer.class))
            .as("안 읽은 알림이 있어야 배지가 뜬다").isPositive();
        assertThat(jdbc.queryForObject(
            "SELECT COUNT(*) FROM notifications WHERE read_at IS NOT NULL", Integer.class))
            .as("읽은 알림도 있어야 읽음 처리 결과를 볼 수 있다").isPositive();
    }

    /**
     * 인증 게시물의 <b>집계 컬럼과 실제 투표 수가 일치</b>하는지 본다.
     *
     * <p>둘은 따로 저장되므로 한쪽만 넣으면 목록의 숫자와 상세의 투표 목록이 어긋나는데,
     * 그 어긋남은 상세를 열어야만 드러난다.
     */
    @Test
    void 인증_게시물의_집계가_실제_투표수와_일치한다() {
        List<Map<String, Object>> posts = jdbc.queryForList(
            "SELECT id, agree_count, unsure_count, reject_count, comment_count FROM quest_proof_posts");

        for (Map<String, Object> post : posts) {
            Long id = ((Number) post.get("id")).longValue();
            for (Map.Entry<String, String> pair : Map.of(
                "agree_count", "AGREE", "unsure_count", "UNSURE", "reject_count", "REJECT").entrySet()) {
                Integer actual = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM quest_proof_votes WHERE post_id = ? AND choice = ?",
                    Integer.class, id, pair.getValue());
                assertThat(((Number) post.get(pair.getKey())).intValue())
                    .as("게시물 %d의 %s가 실제 투표 수와 다르다", id, pair.getKey())
                    .isEqualTo(actual);
            }
            Integer comments = jdbc.queryForObject(
                "SELECT COUNT(*) FROM quest_proof_comments WHERE post_id = ?", Integer.class, id);
            assertThat(((Number) post.get("comment_count")).intValue())
                .as("게시물 %d의 comment_count가 실제 댓글 수와 다르다", id)
                .isEqualTo(comments);
        }
    }

    /** 친구 관계는 양방향 두 행이어야 한다 — 한 행만 넣으면 상대 화면에서 친구가 사라진다. */
    @Test
    void 친구_관계가_양방향으로_들어간다() {
        List<Map<String, Object>> rows = jdbc.queryForList(
            "SELECT user_id, friend_id FROM friendships");

        for (Map<String, Object> row : rows) {
            Long userId = ((Number) row.get("user_id")).longValue();
            Long friendId = ((Number) row.get("friend_id")).longValue();
            Integer reverse = jdbc.queryForObject(
                "SELECT COUNT(*) FROM friendships WHERE user_id = ? AND friend_id = ?",
                Integer.class, friendId, userId);
            assertThat(reverse)
                .as("%d→%d 친구 관계의 반대 방향이 없다", userId, friendId)
                .isEqualTo(1);
        }
    }

    /** 두 번 돌려도 늘지 않는다. 부팅할 때마다 사용자가 12명씩 쌓이면 아무도 눈치채지 못한다. */
    @Test
    void 다시_실행해도_중복_적재되지_않는다() {
        int before = count("users");
        seeder.run(null);
        assertThat(count("users")).isEqualTo(before);
    }

    /**
     * <b>주인공의 오늘 배정에 서울권 LOCATION 퀘스트가 있어야 한다.</b>
     *
     * <p>이것이 없으면 지도·주변 퀘스트·GPS 인증을 눌러 볼 수 없다. 배정은 좌표를 받았을 때만
     * 사용자 주변으로 좁히므로(docs/05 §1-C), 시연자가 앱을 열기 전에는 전국에서 뽑힌다 —
     * 실측에서 서울 계정에 천안 퀘스트가 배정돼 {@code /quests/nearby}가 0건이었다.
     *
     * <p>좌표 범위로 재는 이유는 시드 id가 마이그레이션마다 달라지기 때문이다. 특정 id를 박으면
     * 카탈로그가 바뀔 때 이 테스트가 조용히 다른 것을 재게 된다.
     */
    @Test
    void 주인공의_오늘_배정에_서울권_위치_퀘스트가_있다() {
        Long demoUserId = jdbc.queryForObject(
            "SELECT id FROM users WHERE email = ?", Long.class, DemoDataSeeder.DEMO_EMAIL);

        Integer nearby = jdbc.queryForObject("""
            SELECT COUNT(*) FROM user_daily_quests d JOIN quests q ON q.id = d.quest_id
            WHERE d.user_id = ? AND d.status = 'ASSIGNED'
              AND q.completion_type = 'LOCATION'
              AND q.latitude BETWEEN 37.45 AND 37.65
              AND q.longitude BETWEEN 126.85 AND 127.15
            """, Integer.class, demoUserId);

        assertThat(nearby)
            .as("서울에서 앱을 열었을 때 갈 수 있는 위치 퀘스트가 배정돼 있어야 한다 — "
                + "없으면 지도·주변 퀘스트·GPS 인증 경로를 시연할 수 없다")
            .isPositive();
    }

    /** 사진 있는 게시물과 없는 게시물이 섞여야 두 레이아웃을 함께 확인할 수 있다. */
    @Test
    void 인증_게시물에_사진이_있는_것과_없는_것이_섞여_있다() {
        Integer withPhoto = jdbc.queryForObject(
            "SELECT COUNT(DISTINCT post_id) FROM quest_proof_photos", Integer.class);
        Integer total = jdbc.queryForObject(
            "SELECT COUNT(*) FROM quest_proof_posts", Integer.class);

        assertThat(withPhoto).as("사진이 붙은 게시물이 하나도 없으면 피드가 글만으로 채워진다").isPositive();
        assertThat(withPhoto).as("전부 사진이 있으면 사진 없는 게시물의 모양을 볼 수 없다").isLessThan(total);
    }

    /** 업적은 달성·진행 중이 함께 있어야 달성 표시와 진행률 바를 모두 확인할 수 있다. */
    @Test
    void 업적에_달성과_진행중이_함께_있다() {
        Integer achieved = jdbc.queryForObject(
            "SELECT COUNT(*) FROM user_achievements WHERE achieved_at IS NOT NULL", Integer.class);
        Integer inProgress = jdbc.queryForObject(
            "SELECT COUNT(*) FROM user_achievements WHERE achieved_at IS NULL", Integer.class);

        assertThat(achieved).as("달성한 업적이 없으면 달성 표시를 볼 수 없다").isPositive();
        assertThat(inProgress).as("진행 중인 업적이 없으면 진행률 안내가 사라진다").isPositive();
    }

    /** 친구 코드는 사람이 불러 주는 값이라 접두사와 겹치면 읽기 어색하다. */
    @Test
    void 친구_코드가_접두사와_겹치지_않는다() {
        List<String> codes = jdbc.queryForList(
            "SELECT friend_code FROM users WHERE friend_code IS NOT NULL", String.class);

        assertThat(codes).isNotEmpty();
        assertThat(codes).as("DEMO-DEMO처럼 같은 말이 두 번 들어가면 안 된다")
            .noneMatch(code -> code.startsWith("DEMO-DEMO"));
    }
}
