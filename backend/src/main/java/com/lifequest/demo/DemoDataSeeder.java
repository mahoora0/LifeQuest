package com.lifequest.demo;

import com.lifequest.growth.GrowthService;
import java.awt.Color;
import java.awt.Font;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import javax.imageio.ImageIO;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.core.env.Environment;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.simple.SimpleJdbcInsert;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * 시연·개발용 더미 데이터를 넣는다. <b>운영 데이터가 아니다.</b>
 *
 * <h2>왜 마이그레이션이 아닌가</h2>
 * Flyway로 넣으면 팀원 DB와 운영에 <b>되돌릴 수 없이</b> 들어간다. 적용된 마이그레이션은
 * checksum이 고정돼 내용을 고칠 수 없고, 파일을 지우면 Validate 단계에서 부팅이 죽는다.
 * 시연용 가짜 사용자에게 그 성질을 주면 안 된다.
 *
 * <p>반대로 이 시더는 <b>프로파일이 꺼지면 아무 일도 하지 않고</b>, 클래스를 지우는 것이 곧
 * 회수다. Flyway 이력에도 남지 않는다.
 *
 * <h2>켜는 법</h2>
 * <pre>
 * ./gradlew bootRun --args='--spring.profiles.active=demo'
 * </pre>
 *
 * <h2>무엇이 이것을 막는가 — 프로파일 하나뿐이다</h2>
 * 실질적인 방어는 {@link Profile @Profile("demo")} 하나다. 프로파일을 <b>명시적으로 켜야만</b>
 * 빈이 만들어지고, 켜지 않으면 이 클래스는 존재하지 않는 것과 같다.
 *
 * <p>처음에는 {@code prod} 프로파일과 함께 켜지면 부팅을 실패시키는 가드를 두었으나 걷어냈다.
 * <b>이 저장소에는 {@code prod} 프로파일이 없다</b> — {@code application-prod.yml}도,
 * {@code SPRING_PROFILES_ACTIVE} 설정도 어디에도 없다. 그 조건은 참이 될 수 없었고, 그런데도
 * 문서와 주석이 그것을 작동하는 안전장치라고 단언해 <b>없는 보호를 있다고 믿게 만들었다</b>.
 * 도달하지 않는 코드보다 정확한 설명이 낫다.
 *
 * <p>그래서 남은 위험을 그대로 적는다 — <b>운영 환경에서 이 프로파일을 켜면 시연용 가짜
 * 사용자가 그대로 들어간다.</b> 켜기 전에 대상 DB를 확인하는 것 외에 막는 장치는 없다.
 * 적재 직전 경고 로그를 남기는 이유가 이것이다.
 *
 * <h2>멱등과 재적재</h2>
 * 시연 계정({@code *@lifequest.test})이 <b>하나라도</b> 있으면 통째로 건너뛴다. 주인공 계정만
 * 보면, 그 계정만 지우고 재실행했을 때 나머지 11명이 남아 있어 이메일·닉네임·친구코드
 * UNIQUE에 걸린다.
 *
 * <p>전체가 한 트랜잭션이라 중간에 실패하면 DB에는 아무것도 남지 않는다. 다만 <b>지우는 것은
 * 사용자 한 명을 지우는 것으로 끝나지 않는다</b> — 친구·그룹·게시물·알림 등 열세 테이블이
 * {@code users.id}를 FK로 참조하므로 역순으로 지워야 한다. 절차는
 * {@code docs/08-local-run-guide.md}에 적어 두었다.
 */
@Component
@Profile("demo")
public class DemoDataSeeder implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(DemoDataSeeder.class);

    /** 로그인해서 둘러볼 계정. 모든 관계가 이 사용자를 중심으로 짜여 있다. */
    public static final String DEMO_EMAIL = "demo@lifequest.test";
    private static final String DEMO_PASSWORD = "demo1234!";

    /** 시연 계정임을 화면에서도 알아볼 수 있게 붙이는 접미사. */
    private static final String DEMO_DOMAIN = "@lifequest.test";

    private final JdbcTemplate jdbc;
    private final PasswordEncoder passwordEncoder;
    private final Environment environment;

    public DemoDataSeeder(JdbcTemplate jdbc, PasswordEncoder passwordEncoder, Environment environment) {
        this.jdbc = jdbc;
        this.passwordEncoder = passwordEncoder;
        this.environment = environment;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        // 시연 계정이 하나라도 있으면 건너뛴다. 주인공 계정만 보면, 그것만 지우고 재실행했을 때
        // 나머지 11명이 남아 이메일·닉네임·친구코드 UNIQUE에 걸려 부팅이 죽는다.
        Integer existing = jdbc.queryForObject(
            "SELECT COUNT(*) FROM users WHERE email LIKE ?", Integer.class, "%" + DEMO_DOMAIN);
        if (existing != null && existing > 0) {
            log.info("[demo] 시연 데이터가 이미 있다({}명) — 건너뛴다. 다시 넣으려면 "
                + "docs/08-local-run-guide.md의 회수 절차를 따를 것.", existing);
            return;
        }

        // 대상 DB에 이미 사람이 쓰고 있는지 알린다. 막지는 않는다 — 로컬 개발 DB에도 테스트
        // 계정이 흔히 남아 있어 중단시키면 정작 필요할 때 못 쓴다. 다만 운영 DB에 이 프로파일을
        // 켰다면 이 줄이 유일한 신호이므로 반드시 남긴다.
        Integer others = jdbc.queryForObject(
            "SELECT COUNT(*) FROM users WHERE email NOT LIKE ?", Integer.class, "%" + DEMO_DOMAIN);
        log.warn("[demo] 시연용 가짜 데이터를 적재한다. 이 DB에 이미 있는 사용자: {}명. "
            + "운영 DB가 아닌지 확인할 것 — 프로파일 외에 이것을 막는 장치는 없다.", others);

        LocalDateTime now = LocalDateTime.now();
        Map<String, Long> users = seedUsers(now);
        seedFriendships(users, now);
        Map<String, Long> groups = seedGroups(users, now);
        seedGroupQuests(users, groups, now);
        seedGroupChats(users, groups, now);
        List<Long> completions = seedQuestHistory(users, now);
        seedProofPosts(users, completions, now);
        seedCollections(users, now);
        seedAchievements(users, now);
        seedNotifications(users, now);

        // 비밀번호는 로그에 찍지 않는다. 공용 계정이라 값 자체는 비밀이 아니지만, 운영 로그
        // 수집기에 평문 비밀번호가 남는 모양을 만들면 그 습관이 다른 자리로 옮겨 간다.
        log.info("[demo] 시연 데이터 적재 완료 — 사용자 {}명. 로그인 계정은 {} (비밀번호는 "
            + "docs/08-local-run-guide.md 참조)", users.size(), DEMO_EMAIL);
    }

    // ------------------------------------------------------------------ 사용자

    /**
     * 시연 사용자 12명. <b>레벨은 적지 않고 EXP에서 계산</b>한다 —
     * {@link GrowthService#levelFor(int)}와 어긋난 값을 손으로 적으면 화면의 레벨과 진행률이
     * 서로 다른 근거를 갖게 된다.
     *
     * <p>레벨 분포를 넓게 잡은 이유는 랭킹·친구 목록·프로필이 값의 폭에 따라 다르게 보이기
     * 때문이다. 신규 가입 직후 상태(배도현, EXP 0)도 하나 남겨 <b>빈 화면 자체가 정상으로
     * 보이는지</b> 확인할 수 있게 했다.
     */
    private Map<String, Long> seedUsers(LocalDateTime now) {
        record Persona(String key, String nickname, int totalExp, long characterId, int joinedDaysAgo) {}

        List<Persona> personas = List.of(
            new Persona("demo", "김퀘스트", 6100, 2, 96),      // 주인공
            new Persona("mina", "이미나", 11200, 3, 120),      // 친구 · 활동 많음
            new Persona("junho", "박준호", 3900, 1, 74),       // 친구
            new Persona("sora", "최소라", 23800, 4, 210),      // 친구 · 최고 레벨
            new Persona("daeun", "정다은", 2400, 3, 51),       // 친구
            new Persona("hyunwoo", "강현우", 750, 1, 20),      // 친구 요청을 보내옴
            new Persona("jiyeon", "윤지연", 5700, 2, 88),      // 친구 요청을 보내옴
            new Persona("taemin", "임태민", 1700, 4, 33),      // 주인공이 요청을 보낸 상대
            new Persona("yerin", "한예린", 15800, 3, 160),     // 남 · 검색 결과용
            new Persona("seojun", "오서준", 420, 1, 12),       // 남 · 그룹에서만 만남
            new Persona("nayoung", "신나영", 9500, 2, 105),    // 남 · 그룹에서만 만남
            new Persona("dohyun", "배도현", 0, 1, 1)           // 가입 직후 — 빈 상태 대조군
        );

        SimpleJdbcInsert insert = new SimpleJdbcInsert(jdbc)
            .withTableName("users")
            .usingGeneratedKeyColumns("id");

        String hash = passwordEncoder.encode(DEMO_PASSWORD);
        Map<String, Long> ids = new LinkedHashMap<>();

        for (Persona p : personas) {
            LocalDateTime joinedAt = now.minusDays(p.joinedDaysAgo());
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("email", p.key() + DEMO_DOMAIN);
            row.put("password_hash", hash);
            row.put("nickname", p.nickname());
            row.put("role", "USER");
            row.put("total_exp", p.totalExp());
            row.put("level", GrowthService.levelFor(p.totalExp()));
            row.put("selected_character_id", p.characterId());
            // 친구 코드는 검색으로 서로를 찾는 경로에 쓰인다. VARCHAR(16)이고 가장 긴 것이 12자다.
            // 주인공의 key가 'demo'라 접두사와 겹치므로(DEMO-DEMO) 그 자리만 다른 말을 쓴다.
            String suffix = "demo".equals(p.key()) ? "HERO" : p.key().toUpperCase();
            row.put("friend_code", "DEMO-" + suffix);
            row.put("created_at", joinedAt);
            row.put("updated_at", joinedAt);
            ids.put(p.key(), insert.executeAndReturnKey(row).longValue());
        }
        return ids;
    }

    // ------------------------------------------------------------------ 친구

    /**
     * 친구 관계를 <b>네 가지 상태로</b> 만든다 — 이미 친구 / 받은 요청 / 보낸 요청 / 거절됨.
     * 하나만 만들면 목록·요청 탭·검색 결과가 같은 모양으로만 보여 상태별 분기가 검증되지 않는다.
     *
     * <p>{@code friendships}는 <b>양방향 두 행</b>으로 넣는다 — 조회가 한쪽만 보므로 한 행만
     * 넣으면 상대 화면에서 친구가 사라진다.
     */
    private void seedFriendships(Map<String, Long> u, LocalDateTime now) {
        List<String> friends = List.of("mina", "junho", "sora", "daeun");
        for (int i = 0; i < friends.size(); i++) {
            String friend = friends.get(i);
            LocalDateTime since = now.minusDays(30L - i * 6);
            jdbc.update("INSERT INTO friendships (user_id, friend_id, created_at) VALUES (?, ?, ?)",
                u.get("demo"), u.get(friend), since);
            jdbc.update("INSERT INTO friendships (user_id, friend_id, created_at) VALUES (?, ?, ?)",
                u.get(friend), u.get("demo"), since);
            jdbc.update(
                "INSERT INTO friend_requests (sender_id, receiver_id, status, created_at, responded_at) "
                    + "VALUES (?, ?, 'ACCEPTED', ?, ?)",
                u.get(friend), u.get("demo"), since.minusDays(1), since);
        }

        // 받은 요청 둘 — 요청 탭에 배지가 뜬다
        jdbc.update("INSERT INTO friend_requests (sender_id, receiver_id, status, created_at) VALUES (?, ?, 'PENDING', ?)",
            u.get("hyunwoo"), u.get("demo"), now.minusHours(5));
        jdbc.update("INSERT INTO friend_requests (sender_id, receiver_id, status, created_at) VALUES (?, ?, 'PENDING', ?)",
            u.get("jiyeon"), u.get("demo"), now.minusDays(2));

        // 보낸 요청 하나 — 상대 응답을 기다리는 화면
        jdbc.update("INSERT INTO friend_requests (sender_id, receiver_id, status, created_at) VALUES (?, ?, 'PENDING', ?)",
            u.get("demo"), u.get("taemin"), now.minusDays(1));

        // 거절된 요청 — 재요청 가능 여부를 보는 자리
        jdbc.update(
            "INSERT INTO friend_requests (sender_id, receiver_id, status, created_at, responded_at) "
                + "VALUES (?, ?, 'REJECTED', ?, ?)",
            u.get("demo"), u.get("yerin"), now.minusDays(12), now.minusDays(11));

        // 주인공과 무관한 친구 관계 — 친구의 친구가 보이는 화면이 비지 않게 한다
        jdbc.update("INSERT INTO friendships (user_id, friend_id, created_at) VALUES (?, ?, ?)",
            u.get("mina"), u.get("sora"), now.minusDays(40));
        jdbc.update("INSERT INTO friendships (user_id, friend_id, created_at) VALUES (?, ?, ?)",
            u.get("sora"), u.get("mina"), now.minusDays(40));
    }

    // ------------------------------------------------------------------ 그룹

    /**
     * 그룹을 <b>참여 상태별로</b> 만든다 — 내가 만든 곳 / 참여 중 / 초대받음 / 가입 신청 중 /
     * 미참여 공개 / 비공개.
     *
     * <p>목록·검색·초대함·가입요청함이 각각 다른 조회를 쓰므로, 상태 하나만 만들면 나머지 화면이
     * 전부 빈 채로 남는다.
     */
    private Map<String, Long> seedGroups(Map<String, Long> u, LocalDateTime now) {
        record GroupSpec(String key, String owner, String name, String description,
                         String visibility, int maxMembers, int createdDaysAgo) {}

        List<GroupSpec> specs = List.of(
            new GroupSpec("running", "demo", "한강 러닝 크루",
                "매주 화·목 저녁 한강에서 함께 달립니다. 초보 환영이고 페이스는 각자에 맞춥니다.",
                "PUBLIC", 20, 60),
            new GroupSpec("museum", "mina", "주말 미술관 산책",
                "토요일마다 전시를 하나 골라 같이 보고 근처에서 커피 한잔 합니다.",
                "PUBLIC", 12, 45),
            new GroupSpec("hiking", "sora", "새벽 등산 모임",
                "해 뜨기 전에 올라 정상에서 아침을 맞습니다. 월 2회.",
                "PUBLIC", 15, 30),
            new GroupSpec("reading", "yerin", "독서 기록단",
                "한 달에 한 권, 다 읽으면 인증하고 짧은 감상을 남깁니다.",
                "PUBLIC", 30, 90),
            new GroupSpec("cafe", "nayoung", "동네 카페 탐험",
                "가 본 적 없는 카페를 매주 하나씩 뚫습니다. 지역은 서울 전역.",
                "PUBLIC", 25, 21),
            new GroupSpec("study", "junho", "새벽 기상 스터디",
                "6시 기상 인증. 비공개로 운영합니다.",
                "PRIVATE", 8, 15)
        );

        Map<String, Long> ids = new LinkedHashMap<>();
        SimpleJdbcInsert insert = new SimpleJdbcInsert(jdbc)
            .withTableName("quest_groups")
            .usingGeneratedKeyColumns("id");

        for (GroupSpec s : specs) {
            LocalDateTime createdAt = now.minusDays(s.createdDaysAgo());
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("owner_user_id", u.get(s.owner()));
            row.put("name", s.name());
            row.put("description", s.description());
            row.put("visibility", s.visibility());
            row.put("max_members", s.maxMembers());
            row.put("status", "ACTIVE");
            row.put("created_at", createdAt);
            row.put("updated_at", createdAt);
            ids.put(s.key(), insert.executeAndReturnKey(row).longValue());

            // 소유자는 항상 ACTIVE 멤버여야 한다 — 멤버 목록에서 방장이 빠지면 목록이 어긋난다
            addMember(ids.get(s.key()), u.get(s.owner()), "OWNER", "ACTIVE", null, createdAt);
        }

        // 한강 러닝 크루 — 주인공이 방장. 멤버가 채워져 있어야 멤버 목록·채팅이 산다
        addMember(ids.get("running"), u.get("mina"), "MEMBER", "ACTIVE", u.get("demo"), now.minusDays(55));
        addMember(ids.get("running"), u.get("junho"), "MEMBER", "ACTIVE", u.get("demo"), now.minusDays(48));
        addMember(ids.get("running"), u.get("seojun"), "MEMBER", "ACTIVE", null, now.minusDays(20));
        addMember(ids.get("running"), u.get("nayoung"), "MEMBER", "ACTIVE", null, now.minusDays(11));
        // 방장에게 온 가입 요청 — 승인 대기 화면
        addMember(ids.get("running"), u.get("daeun"), "MEMBER", "PENDING_APPROVAL", null, now.minusDays(1));
        addMember(ids.get("running"), u.get("taemin"), "MEMBER", "PENDING_APPROVAL", null, now.minusHours(9));
        // 나간 사람 — 이력이 남는 상태
        addMember(ids.get("running"), u.get("hyunwoo"), "MEMBER", "LEFT", null, now.minusDays(35));

        // 주말 미술관 산책 — 주인공이 참여 중
        addMember(ids.get("museum"), u.get("demo"), "MEMBER", "ACTIVE", u.get("mina"), now.minusDays(40));
        addMember(ids.get("museum"), u.get("sora"), "MEMBER", "ACTIVE", null, now.minusDays(38));
        addMember(ids.get("museum"), u.get("daeun"), "MEMBER", "ACTIVE", null, now.minusDays(14));

        // 새벽 등산 모임 — 주인공이 초대받고 아직 답하지 않음
        addMember(ids.get("hiking"), u.get("demo"), "MEMBER", "INVITED", u.get("sora"), now.minusDays(3));
        addMember(ids.get("hiking"), u.get("yerin"), "MEMBER", "ACTIVE", null, now.minusDays(25));

        // 독서 기록단 — 주인공이 가입 신청하고 승인 대기
        addMember(ids.get("reading"), u.get("demo"), "MEMBER", "PENDING_APPROVAL", null, now.minusDays(2));
        addMember(ids.get("reading"), u.get("nayoung"), "MEMBER", "ACTIVE", null, now.minusDays(60));
        addMember(ids.get("reading"), u.get("jiyeon"), "MEMBER", "ACTIVE", null, now.minusDays(30));

        // 동네 카페 탐험 — 주인공 미참여. 검색 결과에 뜨는 그룹
        addMember(ids.get("cafe"), u.get("seojun"), "MEMBER", "ACTIVE", null, now.minusDays(10));

        return ids;
    }

    private void addMember(Long groupId, Long userId, String role, String status,
                           Long invitedBy, LocalDateTime at) {
        // 한 번이라도 들어왔던 사람은 joined_at을 갖는다. 도메인의 leave()가 그 값을 지우지
        // 않으므로 탈퇴자에게 NULL을 넣으면 앱이 만들 수 없는 조합이 된다.
        // 초대·가입신청 단계는 아직 멤버가 아니므로 비운다.
        LocalDateTime joinedAt = List.of("ACTIVE", "LEFT", "REMOVED").contains(status) ? at : null;
        LocalDateTime respondedAt = List.of("ACTIVE", "REJECTED", "LEFT").contains(status) ? at : null;
        // 초대는 방치되면 만료된다. 만료 시각이 없으면 영영 남는 초대가 된다
        LocalDateTime expiresAt = "INVITED".equals(status) ? at.plusDays(7) : null;

        jdbc.update("INSERT INTO group_members "
                + "(group_id, user_id, role, status, invited_by_user_id, expires_at, responded_at, joined_at, created_at, updated_at) "
                + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            groupId, userId, role, status, invitedBy, expiresAt, respondedAt, joinedAt, at, at);
    }

    // ------------------------------------------------------------ 그룹 퀘스트

    /**
     * 그룹 퀘스트를 <b>예정·완료·취소</b>로 나눠 넣는다. 참가 신청도 신청/철회 두 상태를 만든다.
     *
     * <p>완료된 건에는 {@code rewarded_at}을 채운다 — 협동 완료는 참가자 전원에게 고정 EXP를
     * 주는 별도 경로이고, 그 흔적이 없으면 완료 화면이 "보상을 못 받은 상태"로 보인다.
     */
    private void seedGroupQuests(Map<String, Long> u, Map<String, Long> g, LocalDateTime now) {
        SimpleJdbcInsert insert = new SimpleJdbcInsert(jdbc)
            .withTableName("group_quests")
            .usingGeneratedKeyColumns("id");

        // 예정 — 참가자를 모으는 중
        Long upcoming = insertGroupQuest(insert, g.get("running"), u.get("demo"),
            "반포 야경 10km", "반포한강공원에서 출발해 잠수교를 돌아옵니다. 완주보다 완주 후 치맥이 목적입니다.",
            "반포한강공원", now.plusDays(3).withHour(19).withMinute(0), "PUBLISHED", 40, null);
        applyParticipant(upcoming, u.get("mina"), "APPLIED", now.minusDays(1), null, null);
        applyParticipant(upcoming, u.get("junho"), "APPLIED", now.minusHours(20), null, null);
        applyParticipant(upcoming, u.get("seojun"), "WITHDRAWN", now.minusDays(2), now.minusHours(6), null);

        // 예정 — 주인공이 이미 신청함
        Long joined = insertGroupQuest(insert, g.get("museum"), u.get("mina"),
            "국립현대미술관 서울관 관람", "이번 주 토요일 오후 2시 로비에서 모입니다. 관람 후 삼청동 산책.",
            "국립현대미술관 서울관", now.plusDays(5).withHour(14).withMinute(0), "PUBLISHED", 40, null);
        applyParticipant(joined, u.get("demo"), "APPLIED", now.minusHours(30), null, null);
        applyParticipant(joined, u.get("sora"), "APPLIED", now.minusDays(3), null, null);

        // 완료 — 주인공이 참가해 보상을 받은 건
        LocalDateTime doneAt = now.minusDays(6).withHour(20).withMinute(30);
        Long done = insertGroupQuest(insert, g.get("running"), u.get("demo"),
            "여의도 벚꽃 야간 러닝", "여의서로를 따라 5km. 사진 찍느라 기록은 포기했습니다.",
            "여의도한강공원", doneAt, "COMPLETED", 40, doneAt.plusHours(2));
        // 보상까지 끝난 참가자는 REWARDED다 — GroupQuestParticipant.reward()가 그렇게 바꾼다.
        // APPLIED로 두면 rewarded_at이 있는데도 화면에는 "신청함"으로 보이고, 철회 가드도 걸리지 않는다.
        applyParticipant(done, u.get("demo"), "REWARDED", doneAt.minusDays(4), null, doneAt.plusHours(2));
        applyParticipant(done, u.get("mina"), "REWARDED", doneAt.minusDays(4), null, doneAt.plusHours(2));
        applyParticipant(done, u.get("nayoung"), "REWARDED", doneAt.minusDays(3), null, doneAt.plusHours(2));

        // 취소 — 목록에서 어떻게 보이는지 확인할 자리
        insertGroupQuest(insert, g.get("running"), u.get("demo"),
            "남산 계단 오르기", "비 예보로 취소했습니다. 다음 주에 다시 잡습니다.",
            "남산공원", now.minusDays(2).withHour(7).withMinute(0), "CANCELLED", 40, null);

        // 다른 그룹에도 하나씩 — 그룹 상세가 비지 않게
        insertGroupQuest(insert, g.get("reading"), u.get("yerin"),
            "이달의 책 완독 인증", "다 읽은 사람은 마지막 장 사진과 함께 한 줄 감상을 올려 주세요.",
            "각자 자리", now.plusDays(9).withHour(21).withMinute(0), "PUBLISHED", 40, null);
        insertGroupQuest(insert, g.get("cafe"), u.get("nayoung"),
            "연남동 신상 카페 3곳", "한 번에 세 곳을 돌면 하루가 갑니다. 나눠 가도 됩니다.",
            "연남동", now.plusDays(7).withHour(13).withMinute(0), "PUBLISHED", 40, null);
    }

    private Long insertGroupQuest(SimpleJdbcInsert insert, Long groupId, Long creatorId,
                                  String title, String description, String placeName,
                                  LocalDateTime scheduledAt, String status, int expReward,
                                  LocalDateTime completedAt) {
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("group_id", groupId);
        row.put("created_by_user_id", creatorId);
        row.put("title", title);
        row.put("description", description);
        row.put("place_name", placeName);
        row.put("scheduled_at", scheduledAt);
        row.put("status", status);
        row.put("exp_reward", expReward);
        row.put("completed_at", completedAt);
        // 생성 시각을 "일정 −7일"로 고정하면 먼 미래의 일정이 <b>아직 오지 않은 시각에 만들어진</b>
        // 것이 된다(일정 +9일 → 생성 +2일). 상대시간 표시가 음수가 되고 목록 정렬도 어긋난다.
        // 참가 신청보다 늦어지는 경우도 같은 이유로 생긴다. 지금보다 뒤로 갈 수 없게 잡는다.
        LocalDateTime createdAt = scheduledAt.minusDays(7);
        LocalDateTime notFuture = LocalDateTime.now().minusDays(5);
        if (createdAt.isAfter(notFuture)) {
            createdAt = notFuture;
        }
        row.put("created_at", createdAt);
        row.put("updated_at", completedAt != null ? completedAt : createdAt);
        return insert.executeAndReturnKey(row).longValue();
    }

    private void applyParticipant(Long groupQuestId, Long userId, String status,
                                  LocalDateTime appliedAt, LocalDateTime withdrawnAt,
                                  LocalDateTime rewardedAt) {
        jdbc.update("INSERT INTO group_quest_participants "
                + "(group_quest_id, user_id, status, applied_at, withdrawn_at, rewarded_at) "
                + "VALUES (?, ?, ?, ?, ?, ?)",
            groupQuestId, userId, status, appliedAt, withdrawnAt, rewardedAt);
    }

    // ------------------------------------------------------------------ 채팅

    /** 한 줄의 대화. 말한 사람과 시각이 섞여야 말풍선 좌우 정렬과 시간 구분선이 드러난다. */
    private record ChatLine(String speaker, String text, int minutesAgo) {}

    /** 채팅은 <b>대화로</b> 넣는다. 한 사람이 연달아 말하는 목록은 말풍선 정렬을 검증하지 못한다. */
    private void seedGroupChats(Map<String, Long> u, Map<String, Long> g, LocalDateTime now) {
        insertChat(g.get("running"), u, now, List.of(
            new ChatLine("mina", "이번 주 화요일 러닝 그대로 가나요?", 2880),
            new ChatLine("demo", "네 7시 반포 집결이요. 비 오면 전날 저녁에 공지할게요", 2875),
            new ChatLine("junho", "저 이번엔 5km만 뛰겠습니다 무릎이 좀", 2860),
            new ChatLine("demo", "무리하지 마세요. 절반 코스 따로 돌아도 됩니다", 2850),
            new ChatLine("seojun", "처음 나가는데 페이스 얼마나 되나요?", 1450),
            new ChatLine("mina", "6분 후반대예요. 대화하면서 뛰는 속도라 편하실 거예요", 1440),
            new ChatLine("nayoung", "지난주 야간 러닝 사진 올려뒀어요 인증 피드에 있습니다", 300),
            new ChatLine("demo", "잘 나왔더라고요. 다음엔 단체 사진도 찍읍시다", 240)
        ));

        insertChat(g.get("museum"), u, now, List.of(
            new ChatLine("mina", "토요일 전시 확정했습니다. 2시 로비예요", 5000),
            new ChatLine("sora", "좋아요. 도슨트 시간 맞춰 가면 좋을 것 같은데 3시에 있대요", 4980),
            new ChatLine("demo", "그럼 2시에 만나서 먼저 한 바퀴 돌고 도슨트 듣는 걸로", 4950),
            new ChatLine("daeun", "저는 조금 늦을 것 같아요. 3시 전에는 도착합니다", 2000)
        ));
    }

    private void insertChat(Long groupId, Map<String, Long> u, LocalDateTime now, List<ChatLine> lines) {
        for (ChatLine line : lines) {
            jdbc.update(
                "INSERT INTO group_chat_messages (group_id, sender_user_id, content, created_at) VALUES (?, ?, ?, ?)",
                groupId, u.get(line.speaker()), line.text(), now.minusMinutes(line.minutesAgo()));
        }
    }

    // -------------------------------------------------------------- 퀘스트 이력

    /**
     * 완료 이력을 넣는다. 인증 게시물이 {@code quest_completion_id}를 반드시 참조하므로
     * <b>게시물보다 먼저</b> 있어야 한다.
     *
     * <p>배정({@code user_daily_quests})도 함께 만든다 — 완료만 있고 배정이 없으면 이력 조회가
     * 조인에서 떨어져 화면에 아무것도 안 나온다.
     *
     * @return 인증 게시물을 붙일 완료 id 목록
     */
    private List<Long> seedQuestHistory(Map<String, Long> u, LocalDateTime now) {
        // 시드 카탈로그에서 완료 이력에 쓸 퀘스트를 고른다. 좌표가 있는 것과 없는 것을 섞어
        // 위치 인증과 직접 완료가 이력에 함께 남게 한다
        List<Long> locationQuests = jdbc.queryForList(
            "SELECT id FROM quests WHERE completion_type = 'LOCATION' AND is_active = TRUE "
                + "AND is_location_template = FALSE ORDER BY id LIMIT 6", Long.class);
        List<Long> selfQuests = jdbc.queryForList(
            "SELECT id FROM quests WHERE completion_type = 'SELF_REPORT' AND is_active = TRUE "
                + "ORDER BY id LIMIT 6", Long.class);

        // 아래 entries가 인덱스 0~5를 전부 쓰므로 6건 미만이면 IndexOutOfBounds가 난다.
        // isEmpty()로 두면 팀원이 위치 퀘스트를 비활성으로 내리는 순간 경고가 아니라 부팅 실패다.
        int needed = 6;
        if (locationQuests.size() < needed || selfQuests.size() < needed) {
            log.warn("[demo] 퀘스트 카탈로그가 모자라 완료 이력을 만들지 않는다 "
                + "(LOCATION {}건 / SELF_REPORT {}건, 각 {}건 필요)",
                locationQuests.size(), selfQuests.size(), needed);
            return List.of();
        }

        record Entry(String user, boolean location, int index, int daysAgo) {}

        List<Entry> entries = List.of(
            new Entry("demo", true, 0, 1),
            new Entry("demo", false, 0, 2),
            new Entry("demo", true, 1, 4),
            new Entry("demo", false, 1, 5),
            new Entry("demo", false, 2, 9),
            new Entry("mina", true, 2, 1),
            new Entry("mina", false, 3, 3),
            new Entry("sora", true, 3, 2),
            new Entry("junho", false, 4, 6),
            new Entry("nayoung", true, 4, 3),
            new Entry("daeun", false, 5, 7),
            new Entry("yerin", true, 5, 8)
        );

        SimpleJdbcInsert assignInsert = new SimpleJdbcInsert(jdbc)
            .withTableName("user_daily_quests").usingGeneratedKeyColumns("id");
        SimpleJdbcInsert completeInsert = new SimpleJdbcInsert(jdbc)
            .withTableName("quest_completions").usingGeneratedKeyColumns("id");

        List<Long> completionIds = new ArrayList<>();
        for (Entry e : entries) {
            Long questId = e.location() ? locationQuests.get(e.index()) : selfQuests.get(e.index());
            Long userId = u.get(e.user());
            LocalDateTime completedAt = now.minusDays(e.daysAgo()).withHour(18).withMinute(20);
            LocalDate assignedDate = completedAt.toLocalDate();

            Map<String, Object> assign = new LinkedHashMap<>();
            assign.put("user_id", userId);
            assign.put("quest_id", questId);
            assign.put("assigned_date", assignedDate);
            assign.put("status", "COMPLETED");
            assign.put("expires_at", assignedDate.plusDays(1).atTime(4, 0));
            Long assignmentId = assignInsert.executeAndReturnKey(assign).longValue();

            Map<String, Object> completion = new LinkedHashMap<>();
            completion.put("user_daily_quest_id", assignmentId);
            completion.put("user_id", userId);
            completion.put("quest_id", questId);
            completion.put("completed_at", completedAt);
            if (e.location()) {
                // 위치 인증 건은 판정에 쓰인 좌표와 거리가 남아야 상세 화면이 채워진다
                Map<String, Object> q = jdbc.queryForMap(
                    "SELECT latitude, longitude FROM quests WHERE id = ?", questId);
                completion.put("verified_latitude", q.get("latitude"));
                completion.put("verified_longitude", q.get("longitude"));
                completion.put("distance_m", 12.4 + e.index() * 7.3);
                completion.put("accuracy_m", 8.0 + e.index());
            }
            completionIds.add(completeInsert.executeAndReturnKey(completion).longValue());

            // 완료했으면 EXP 로그도 남는다 — 성장 그래프가 비지 않게
            Integer reward = jdbc.queryForObject(
                "SELECT exp_reward FROM quests WHERE id = ?", Integer.class, questId);
            jdbc.update("INSERT INTO exp_logs (user_id, source_type, source_id, exp_amount, created_at) "
                    + "VALUES (?, 'QUEST_COMPLETION', ?, ?, ?)",
                userId, completionIds.get(completionIds.size() - 1), reward, completedAt);
        }

        // ★ 오늘 일간 배정은 슬롯 수(3)를 채워야 한다.
        //
        // getTodayQuests는 그 트랙의 미만료 배정이 하나라도 있으면 지연 생성을 건너뛴다. 두
        // 건만 넣으면 나머지 한 칸을 아무도 채우지 않아 "트랙당 3개" 계약과 어긋난 홈 화면이
        // 하루 종일 시연된다 — 화면은 정상으로 보이므로 눈으로는 안 걸린다.
        assignPending(assignInsert, u.get("demo"), selfQuests.get(3), now);
        assignPending(assignInsert, u.get("demo"), selfQuests.get(4), now);

        // ★ 서울권 LOCATION 하나를 오늘 자리에 고정한다.
        //
        // 이것이 없으면 지도·주변 퀘스트·GPS 인증을 <b>눌러 볼 수 없다</b>. 배정은 좌표를 받았을
        // 때만 사용자 주변으로 좁히는데(§1-C), 시연자가 앱을 열기 전에는 그 좌표가 없어 전국에서
        // 뽑힌다 — 실측에서 서울 계정에 천안 퀘스트가 배정돼 `/quests/nearby`가 0건이었다.
        //
        // 완료 이력에 이미 쓴 퀘스트는 뺀다. 같은 주기에 두 번 배정하면
        // UNIQUE(user_id, quest_id, assigned_date)에 걸린다.
        List<Long> usedQuestIds = jdbc.queryForList(
            "SELECT quest_id FROM user_daily_quests WHERE user_id = ?", Long.class, u.get("demo"));
        Long seoulLocation = findSeoulDailyLocationQuest(usedQuestIds);
        if (seoulLocation != null) {
            assignPending(assignInsert, u.get("demo"), seoulLocation, now);
        } else {
            log.warn("[demo] 서울권 일간 LOCATION 퀘스트를 찾지 못했다 — 지도·GPS 인증 시연 경로가 빈다");
        }

        return completionIds;
    }

    /** 서울 도심에서 갈 수 있는 일간 LOCATION 퀘스트 하나. 없으면 {@code null}. */
    private Long findSeoulDailyLocationQuest(List<Long> excluded) {
        // 좌표 범위로 고르는 이유는 시드 id가 마이그레이션마다 달라지기 때문이다 —
        // 특정 id를 박아 두면 카탈로그가 바뀔 때 조용히 엉뚱한 퀘스트를 집는다.
        String sql = """
            SELECT id FROM quests
            WHERE completion_type = 'LOCATION' AND cadence = 'DAILY'
              AND is_active = TRUE AND is_location_template = FALSE
              AND latitude BETWEEN 37.45 AND 37.65
              AND longitude BETWEEN 126.85 AND 127.15
            ORDER BY id
            """;
        List<Long> candidates = jdbc.queryForList(sql, Long.class);
        return candidates.stream().filter(id -> !excluded.contains(id)).findFirst().orElse(null);
    }

    private void assignPending(SimpleJdbcInsert insert, Long userId, Long questId, LocalDateTime now) {
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("user_id", userId);
        row.put("quest_id", questId);
        row.put("assigned_date", now.toLocalDate());
        row.put("status", "ASSIGNED");
        row.put("expires_at", now.toLocalDate().plusDays(1).atTime(4, 0));
        insert.execute(row);
    }

    // -------------------------------------------------------------- 인증 게시물

    /**
     * 인증 게시물을 <b>상태별로</b> 넣는다 — 투표 중 / 검증됨 / 애매함.
     *
     * <p>집계 컬럼({@code agree_count} 등)은 투표 행과 <b>따로 저장</b>되므로 둘을 함께 넣는다.
     * 한쪽만 넣으면 목록의 숫자와 상세의 투표 목록이 어긋나는데, 그 어긋남은 상세를 열어야만
     * 드러난다.
     */
    private void seedProofPosts(Map<String, Long> u, List<Long> completions, LocalDateTime now) {
        // 아래에서 인덱스 9까지 참조하므로 10건이 있어야 한다. 8로 두면 목록이 8~9건일 때
        // 경고 대신 IndexOutOfBounds로 죽는다.
        if (completions.size() < 10) {
            log.warn("[demo] 완료 이력이 {}건뿐이라 인증 게시물을 만들지 않는다(10건 필요)",
                completions.size());
            return;
        }

        SimpleJdbcInsert insert = new SimpleJdbcInsert(jdbc)
            .withTableName("quest_proof_posts").usingGeneratedKeyColumns("id");

        // 검증 완료 — 찬성이 충분히 모인 글
        Long verified = insertPost(insert, u.get("mina"), completions.get(5),
            "퇴근하고 바로 달려갔는데 노을이 딱 맞았습니다. 오늘 안 나갔으면 후회할 뻔했어요.",
            "VERIFIED", now.minusDays(1).withHour(19).withMinute(40));
        vote(verified, u.get("demo"), "AGREE", now.minusDays(1).withHour(20));
        vote(verified, u.get("sora"), "AGREE", now.minusDays(1).withHour(21));
        vote(verified, u.get("junho"), "AGREE", now.minusHours(20));
        vote(verified, u.get("nayoung"), "AGREE", now.minusHours(18));
        comment(verified, u.get("sora"), "사진 색감 좋네요. 그 시간대에 가야겠어요", now.minusHours(19));
        comment(verified, u.get("demo"), "저도 같은 코스 돌았는데 30분 차이로 놓쳤습니다", now.minusHours(17));

        // 투표 중 — 주인공이 아직 투표하지 않은 글(피드 첫 탭이 비지 않게)
        Long pending = insertPost(insert, u.get("nayoung"), completions.get(9),
            "처음 와 본 곳인데 생각보다 조용해서 좋았습니다. 다음엔 책 들고 와야지.",
            "VOTING", now.minusHours(6));
        vote(pending, u.get("mina"), "AGREE", now.minusHours(5));

        // 투표 중 — 주인공이 이미 투표한 글(같은 탭에서 상태가 갈리는지)
        Long voted = insertPost(insert, u.get("sora"), completions.get(7),
            "정상까지 1시간 반 걸렸습니다. 아침 공기가 완전히 다르네요.",
            "VOTING", now.minusDays(2).withHour(8).withMinute(10));
        vote(voted, u.get("demo"), "AGREE", now.minusDays(2).withHour(9));
        vote(voted, u.get("yerin"), "AGREE", now.minusDays(2).withHour(11));
        comment(voted, u.get("demo"), "새벽 등산 모임 초대 감사합니다. 이번 주에 답 드릴게요", now.minusDays(2).withHour(9).withMinute(5));

        // 애매함 — 판정이 갈린 글
        // ★ 판정은 UNSURE를 세지 않는다 — ProofPostStatus.of는 decided = AGREE + REJECT로
        // 정족수를 재고 그 안의 찬성 비율만 본다. UNSURE만 모으면 정족수에 닿지 않아 규칙상
        // VOTING이고, 시연 중 누가 한 표를 던지는 순간 재판정으로 상태가 되돌아간다.
        // 실제로 UNCLEAR이 되려면 찬반이 갈려야 하므로 REJECT 표를 넣는다.
        Long unclear = insertPost(insert, u.get("junho"), completions.get(8),
            "사진을 깜빡해서 영수증만 남았습니다. 다녀온 건 확실한데 증거가 약하네요.",
            "UNCLEAR", now.minusDays(6).withHour(21));
        vote(unclear, u.get("mina"), "AGREE", now.minusDays(5).withHour(10));
        vote(unclear, u.get("sora"), "AGREE", now.minusDays(5).withHour(12));
        vote(unclear, u.get("demo"), "REJECT", now.minusDays(6).withHour(22));
        vote(unclear, u.get("yerin"), "REJECT", now.minusDays(5).withHour(14));
        vote(unclear, u.get("nayoung"), "UNSURE", now.minusDays(5).withHour(16));
        comment(unclear, u.get("mina"), "영수증에 시간 찍혀 있으면 저는 인정합니다", now.minusDays(5).withHour(10).withMinute(30));

        // 주인공이 올린 글 — 내 게시물 목록이 비지 않게
        Long mine = insertPost(insert, u.get("demo"), completions.get(0),
            "오늘의 퀘스트로 나온 김에 처음 가 봤습니다. 걸어서 갈 만한 거리였네요.",
            "VOTING", now.minusHours(30));
        vote(mine, u.get("mina"), "AGREE", now.minusHours(28));
        vote(mine, u.get("daeun"), "AGREE", now.minusHours(26));
        // 내가 쓴 글에도 댓글이 있어야 한다 — 없으면 내 게시물 상세만 댓글 영역이 빈다
        comment(mine, u.get("mina"), "저도 거기 가 봤는데 생각보다 가깝더라고요", now.minusHours(27));
        comment(mine, u.get("junho"), "다음엔 같이 가시죠", now.minusHours(24));

        seedProofPhotos(List.of(verified, voted, mine), now);
        syncProofCounts();
    }

    /**
     * {@code SimpleJdbcInsert}는 지정하지 않은 컬럼에 <b>명시적 NULL</b>을 넣는다 — DEFAULT가
     * 적용되지 않으므로 {@code NOT NULL DEFAULT 0}인 집계 컬럼을 여기서 0으로 초기화한다.
     * (실측: 빼고 넣었더니 {@code NULL not allowed for column "agree_count"}로 부팅이 죽었다.)
     */
    private Long insertPost(SimpleJdbcInsert insert, Long userId, Long completionId,
                            String content, String status, LocalDateTime createdAt) {
        Long questId = jdbc.queryForObject(
            "SELECT quest_id FROM quest_completions WHERE id = ?", Long.class, completionId);
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("user_id", userId);
        row.put("quest_completion_id", completionId);
        row.put("quest_id", questId);
        row.put("content", content);
        row.put("status", status);
        row.put("agree_count", 0);
        row.put("unsure_count", 0);
        row.put("reject_count", 0);
        row.put("comment_count", 0);
        row.put("created_at", createdAt);
        row.put("updated_at", createdAt);
        return insert.executeAndReturnKey(row).longValue();
    }

    private void vote(Long postId, Long voterId, String choice, LocalDateTime at) {
        jdbc.update("INSERT INTO quest_proof_votes (post_id, voter_user_id, choice, created_at) VALUES (?, ?, ?, ?)",
            postId, voterId, choice, at);
    }

    private void comment(Long postId, Long authorId, String content, LocalDateTime at) {
        jdbc.update("INSERT INTO quest_proof_comments (post_id, author_user_id, content, created_at) VALUES (?, ?, ?, ?)",
            postId, authorId, content, at);
    }

    /**
     * 집계 컬럼을 <b>실제 행을 세서</b> 채운다. 게시물·투표·댓글을 전부 넣은 뒤 마지막에 한 번만
     * 부른다.
     *
     * <p>숫자를 손으로 적으면 투표를 하나 더 넣거나 뺄 때 조용히 어긋난다 — 목록에는 적어 둔
     * 숫자가, 상세에는 실제 투표가 나오므로 <b>상세를 열어야만</b> 드러난다.
     *
     * <p>게시물별로 부르지 않는 이유는 <b>순서 의존이 생기기 때문</b>이다. 실제로 게시물마다
     * 호출하도록 짰다가, 댓글을 집계 뒤에 넣는 자리에서 {@code comment_count}가 0으로 남았다.
     * 전체를 한 번에 세면 언제 무엇을 넣었는지가 결과를 바꾸지 못한다.
     */
    private void syncProofCounts() {
        jdbc.update("""
            UPDATE quest_proof_posts p SET
                agree_count   = (SELECT COUNT(*) FROM quest_proof_votes v
                                  WHERE v.post_id = p.id AND v.choice = 'AGREE'),
                unsure_count  = (SELECT COUNT(*) FROM quest_proof_votes v
                                  WHERE v.post_id = p.id AND v.choice = 'UNSURE'),
                reject_count  = (SELECT COUNT(*) FROM quest_proof_votes v
                                  WHERE v.post_id = p.id AND v.choice = 'REJECT'),
                comment_count = (SELECT COUNT(*) FROM quest_proof_comments c
                                  WHERE c.post_id = p.id)
            """);
    }

    // ------------------------------------------------------------------ 사진

    /**
     * 인증 사진을 붙인다. <b>DB 행만 넣으면 안 되고 파일도 있어야 한다</b> — 앱은
     * {@code /uploads/proof/*}를 실제로 받아 오므로 행만 있으면 깨진 이미지가 된다.
     *
     * <p>그림 자체는 단색 배경에 글자 몇 자다. 시연에서 확인하려는 것은 "사진이 있는 게시물과
     * 없는 게시물이 다르게 보이는가"이지 사진의 내용이 아니다.
     *
     * <p><b>실패해도 시더를 멈추지 않는다.</b> 파일 쓰기는 DB 트랜잭션 밖의 부작용이라
     * 권한·경로 문제로 실패할 수 있는데, 그 때문에 나머지 시연 데이터까지 못 들어가면 손해가 크다.
     */
    private void seedProofPhotos(List<Long> postIds, LocalDateTime now) {
        String uploadDir = environment.getProperty("app.upload.directory", "uploads");
        Path dir = Path.of(uploadDir, "proof");
        try {
            Files.createDirectories(dir);
        } catch (IOException e) {
            log.warn("[demo] 인증 사진 디렉터리를 만들지 못했다 ({}) — 사진 없이 진행한다", e.getMessage());
            return;
        }

        String[] captions = {"인증 사진", "오늘의 기록", "다녀왔습니다"};
        Color[] colors = {new Color(0x4C, 0x7E, 0xF3), new Color(0x2E, 0xA8, 0x76), new Color(0xE8, 0x8B, 0x3C)};

        for (int i = 0; i < postIds.size(); i++) {
            String fileName = "demo-proof-" + (i + 1) + ".png";
            jdbc.update("INSERT INTO quest_proof_photos (post_id, image_url, sort_order) VALUES (?, ?, ?)",
                postIds.get(i), "/uploads/proof/" + fileName, 0);

            // 파일은 커밋이 끝난 뒤에 쓴다. 트랜잭션 안에서 쓰면 뒤 단계가 실패해 롤백될 때
            // 디스크에만 남는 고아 파일이 생긴다 — 롤백은 파일을 되돌리지 못한다.
            Path file = dir.resolve(fileName);
            String caption = captions[i % captions.length];
            Color color = colors[i % colors.length];
            afterCommit(() -> writePlaceholderImage(file, caption, color));
        }
    }


    /** 트랜잭션이 커밋된 뒤에 실행한다. 동기화가 없으면(트랜잭션 밖) 즉시 실행한다. */
    private void afterCommit(Runnable action) {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    action.run();
                }
            });
        } else {
            action.run();
        }
    }

    /** 단색 배경에 글자 몇 자를 얹은 자리표 이미지. 실패해도 예외를 밖으로 내보내지 않는다. */
    private void writePlaceholderImage(Path file, String caption, Color color) {
        try {
            BufferedImage image = new BufferedImage(480, 360, BufferedImage.TYPE_INT_RGB);
            Graphics2D g = image.createGraphics();
            g.setColor(color);
            g.fillRect(0, 0, 480, 360);
            g.setColor(Color.WHITE);
            g.setFont(new Font(Font.SANS_SERIF, Font.BOLD, 28));
            g.drawString(caption, 40, 190);
            g.dispose();
            ImageIO.write(image, "png", file.toFile());
        } catch (IOException | RuntimeException e) {
            log.warn("[demo] 인증 사진 {} 생성 실패 ({}) — 그 게시물은 이미지가 깨져 보인다",
                file.getFileName(), e.getMessage());
        }
    }

    // ------------------------------------------------------------------ 업적

    /**
     * 업적을 <b>달성·진행 중 두 상태로</b> 넣는다.
     *
     * <p>카탈로그만 있고 이력이 없으면 업적 화면이 전부 미달성으로만 보여, 달성 표시·진행률 바가
     * 어떻게 그려지는지 확인할 수 없다.
     *
     * <p>단계(achievement_steps)가 있는 업적은 <b>중간 단계까지만</b> 올린다 — 끝까지 채우면
     * "다음 단계까지 얼마" 안내가 사라진다.
     */
    private void seedAchievements(Map<String, Long> u, LocalDateTime now) {
        List<Map<String, Object>> achievements = jdbc.queryForList(
            "SELECT a.id, (SELECT COUNT(*) FROM achievement_steps s WHERE s.achievement_id = a.id) AS steps, "
                + "(SELECT MIN(s.required_count) FROM achievement_steps s WHERE s.achievement_id = a.id) AS first_target "
                + "FROM achievements a WHERE a.is_secret = FALSE ORDER BY a.display_order, a.id LIMIT 6");

        if (achievements.isEmpty()) {
            log.warn("[demo] 업적 카탈로그가 비어 있어 달성 이력을 만들지 않는다");
            return;
        }

        for (int i = 0; i < achievements.size(); i++) {
            Map<String, Object> a = achievements.get(i);
            Long achievementId = ((Number) a.get("id")).longValue();
            int steps = ((Number) a.get("steps")).intValue();
            int firstTarget = a.get("first_target") == null ? 1 : ((Number) a.get("first_target")).intValue();

            boolean achieved = i < 3;                       // 앞 셋은 달성, 뒤는 진행 중
            int currentStep = achieved ? Math.min(1, steps) : 0;
            int currentValue = achieved ? firstTarget : Math.max(0, firstTarget - 1);

            jdbc.update("INSERT INTO user_achievements "
                    + "(user_id, achievement_id, current_value, current_step, achieved_at, updated_at) "
                    + "VALUES (?, ?, ?, ?, ?, ?)",
                u.get("demo"), achievementId, currentValue, currentStep,
                achieved ? now.minusDays(10L - i * 3) : null, now.minusDays(1));
        }
    }

    // ------------------------------------------------------------ 도감 · 칭호

    /**
     * 도감과 칭호를 <b>부분만</b> 채운다. 전부 채우면 "수집 중"이라는 상태 자체가 화면에서
     * 사라지고, 하나도 없으면 도감이 통째로 빈 격자가 된다.
     */
    private void seedCollections(Map<String, Long> u, LocalDateTime now) {
        // 일간 퀘스트에 연결된 도감은 완료 이력에 넣은 것만 채운다. 오늘 배정되는 퀘스트가
        // 바로 그 일간 위치 퀘스트이고, 그것을 완료하는 순간 "도감에 도장이 찍히는" 장면이 나오는데,
        // 여기서 미리 채워 버리면 INSERT IGNORE가 0을 반환해 그 장면이 통째로 사라진다.
        // (id 순으로 담으면 일간 연결 도감이 앞자리라 LIMIT이 넷을 전부 삼킨다 — 순서에 기대지 않는다.)
        List<Long> items = jdbc.queryForList("""
            SELECT li.id FROM lifedex_items li
            WHERE li.id NOT IN (
                SELECT q.lifedex_item_id FROM quests q
                WHERE q.cadence = 'DAILY' AND q.lifedex_item_id IS NOT NULL
                  AND q.id NOT IN (SELECT udq.quest_id FROM user_daily_quests udq
                                   WHERE udq.user_id = ? AND udq.status = 'COMPLETED')
            )
            ORDER BY li.id LIMIT 8
            """, Long.class, u.get("demo"));
        for (int i = 0; i < items.size(); i++) {
            // 주인공은 절반 조금 넘게, 고레벨 사용자는 더 많이 모은 상태로 둔다
            jdbc.update("INSERT INTO user_lifedex (user_id, lifedex_item_id, collected_at) VALUES (?, ?, ?)",
                u.get("demo"), items.get(i), now.minusDays(20L - i * 2));
            if (i < 6) {
                jdbc.update("INSERT INTO user_lifedex (user_id, lifedex_item_id, collected_at) VALUES (?, ?, ?)",
                    u.get("sora"), items.get(i), now.minusDays(40L - i * 3));
            }
        }

        List<Long> titles = jdbc.queryForList("SELECT id FROM titles ORDER BY id LIMIT 3", Long.class);
        for (int i = 0; i < titles.size(); i++) {
            jdbc.update("INSERT INTO user_titles (user_id, title_id, source_type, source_id, acquired_at) "
                    + "VALUES (?, ?, 'LEVEL', ?, ?)",
                u.get("demo"), titles.get(i), titles.get(i), now.minusDays(30L - i * 8));
        }
        if (!titles.isEmpty()) {
            // 대표 칭호가 비어 있으면 프로필 상단이 허전하다
            jdbc.update("UPDATE users SET representative_title_id = ? WHERE id = ?",
                titles.get(titles.size() - 1), u.get("demo"));
        }

        // 프로필 아이템도 지급한다 — 칭호만 있으면 '받은 보상' 화면의 아이템 칸이 빈 채로 남는다
        List<Long> profileItems = jdbc.queryForList(
            "SELECT id FROM profile_items ORDER BY id LIMIT 2", Long.class);
        for (int i = 0; i < profileItems.size(); i++) {
            jdbc.update("INSERT INTO user_profile_items "
                    + "(user_id, profile_item_id, source_type, source_id, acquired_at) "
                    + "VALUES (?, ?, 'LEVEL', ?, ?)",
                u.get("demo"), profileItems.get(i), profileItems.get(i), now.minusDays(25L - i * 10));
        }
    }

    // ------------------------------------------------------------------ 알림

    /** 읽음·안읽음을 섞는다. 전부 읽음이면 배지가 안 뜨고, 전부 안읽음이면 읽음 처리가 검증되지 않는다. */
    private void seedNotifications(Map<String, Long> u, LocalDateTime now) {
        record Noti(String kind, String title, String route, int hoursAgo, boolean read) {}

        List<Noti> list = List.of(
            new Noti("FRIEND_REQUEST", "강현우님이 친구 요청을 보냈어요", "/friends/requests", 5, false),
            new Noti("FRIEND_REQUEST", "윤지연님이 친구 요청을 보냈어요", "/friends/requests", 48, false),
            new Noti("QUEST_ASSIGNED", "오늘의 퀘스트가 도착했어요", "/", 9, false),
            new Noti("ACHIEVEMENT", "'동네 탐험가' 칭호를 얻었어요", "/achievements", 72, true),
            new Noti("FRIEND_ACCEPTED", "정다은님과 친구가 되었어요", "/friends", 120, true),
            new Noti("QUEST_ASSIGNED", "이번 주 퀘스트가 갱신됐어요", "/quests", 96, true)
        );

        for (Noti n : list) {
            LocalDateTime createdAt = now.minusHours(n.hoursAgo());
            jdbc.update("INSERT INTO notifications (user_id, kind, title, route, read_at, created_at) "
                    + "VALUES (?, ?, ?, ?, ?, ?)",
                u.get("demo"), n.kind(), n.title(), n.route(),
                n.read() ? createdAt.plusHours(1) : null, createdAt);
        }
    }
}
