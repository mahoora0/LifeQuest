package com.lifequest.proof;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.lifequest.quest.domain.CompletionType;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.domain.QuestCadence;
import com.lifequest.quest.domain.QuestCreator;
import com.lifequest.quest.domain.QuestGrade;
import com.lifequest.quest.domain.UserDailyQuest;
import com.lifequest.quest.dto.QuestCompletionRequest;
import com.lifequest.quest.repository.QuestRepository;
import com.lifequest.quest.repository.UserDailyQuestRepository;
import com.lifequest.quest.service.QuestCompletionService;
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

/**
 * 인증 광장의 부정 이용 방지 규칙과 판정 흐름을 고정한다.
 *
 * <p>여기서 확인하는 규칙은 전부 화면이 아니라 서버에서 막아야 하는 것들이다 — 앱에서
 * 버튼을 숨기는 것만으로는 요청 자체를 막지 못한다.
 *
 * <p>테스트마다 다른 이메일과 배정을 써서 DB에 남는 상태가 서로 섞이지 않게 한다.
 */
@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
class QuestProofFlowIntegrationTests {

    /** 설정 기본값. {@code application-test.yml}에 {@code app.proof}가 없어 이 값이 쓰인다. */
    private static final int MIN_VOTES = 3;
    private static final int DAILY_VOTE_EXP_GRANTS = 5;

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private QuestRepository questRepository;

    @Autowired
    private UserDailyQuestRepository userDailyQuestRepository;

    @Autowired
    private QuestCompletionService questCompletionService;

    @Test
    void 완료_기록_하나에는_게시물을_하나만_올릴_수_있다() throws Exception {
        Account author = signUp("once@lifequest.test", "한번모험가");
        long completionId = completeQuest(author);

        createPost(author.token(), completionId).andExpect(status().isCreated());

        createPost(author.token(), completionId)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("PROOF_ALREADY_POSTED"));
    }

    @Test
    void 남의_완료_기록으로는_게시물을_올릴_수_없다() throws Exception {
        Account author = signUp("owner@proof.test", "주인모험가");
        Account stranger = signUp("stranger@proof.test", "남의모험가");
        long completionId = completeQuest(author);

        // 존재 여부와 소유권 실패를 구분해 알리지 않는다 — 남의 완료 기록 ID를 훑어
        // 무엇이 있는지 알아낼 수 있어야 할 이유가 없다.
        createPost(stranger.token(), completionId)
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("RESOURCE_NOT_FOUND"));
    }

    @Test
    void 자기_게시물에는_투표할_수_없다() throws Exception {
        Account author = signUp("self@proof.test", "자기모험가");
        long postId = createPostAndGetId(author);

        vote(author.token(), postId, "AGREE")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("CANNOT_VOTE_OWN_PROOF"));
    }

    @Test
    void 같은_게시물에_두_번_투표할_수_없다() throws Exception {
        Account author = signUp("twice-author@proof.test", "이중모험가");
        Account voter = signUp("twice-voter@proof.test", "이중투표자");
        long postId = createPostAndGetId(author);

        vote(voter.token(), postId, "AGREE").andExpect(status().isOk());

        // 번복도 허용하지 않는다. 선택지를 바꿔도 같은 제약에 걸려야 한다.
        vote(voter.token(), postId, "REJECT")
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("PROOF_ALREADY_VOTED"));
    }

    @Test
    void 유효표가_기준을_채우면_판정이_확정된다() throws Exception {
        Account author = signUp("verify-author@proof.test", "판정모험가");
        long postId = createPostAndGetId(author);

        for (int index = 0; index < MIN_VOTES - 1; index++) {
            Account voter = signUp("verify-voter%d@proof.test".formatted(index), "판정투표자%d".formatted(index));
            vote(voter.token(), postId, "AGREE")
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.post.status").value("VOTING"));
        }

        Account last = signUp("verify-voter-last@proof.test", "판정마지막");
        vote(last.token(), postId, "AGREE")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.post.status").value("VERIFIED"))
                .andExpect(jsonPath("$.data.post.decidedVoteCount").value(MIN_VOTES));
    }

    @Test
    void 판단하기_어려워요는_유효표에_들어가지_않는다() throws Exception {
        Account author = signUp("unsure-author@proof.test", "모호모험가");
        long postId = createPostAndGetId(author);

        // UNSURE만 기준 수만큼 모아도 판정이 시작되면 안 된다.
        for (int index = 0; index < MIN_VOTES; index++) {
            Account voter = signUp("unsure-voter%d@proof.test".formatted(index), "모호투표자%d".formatted(index));
            vote(voter.token(), postId, "UNSURE")
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.post.status").value("VOTING"))
                    .andExpect(jsonPath("$.data.post.decidedVoteCount").value(0));
        }
    }

    @Test
    void 투표_EXP는_하루_지급_횟수를_넘지_않는다() throws Exception {
        Account voter = signUp("limit-voter@proof.test", "한도투표자");

        // 한도만큼은 지급되고, 그 다음부터는 투표는 되지만 EXP가 0이어야 한다.
        for (int index = 0; index <= DAILY_VOTE_EXP_GRANTS; index++) {
            Account author = signUp("limit-author%d@proof.test".formatted(index), "한도작성자%d".formatted(index));
            long postId = createPostAndGetId(author);

            int expected = index < DAILY_VOTE_EXP_GRANTS ? 1 : 0;
            vote(voter.token(), postId, "AGREE")
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.expGained").value(expected));
        }
    }

    @Test
    void 게시물을_올리면_퀘스트명이_완료_기록에서_따라온다() throws Exception {
        Account author = signUp("title@proof.test", "제목모험가");
        long completionId = completeQuest(author);

        MvcResult result = createPost(author.token(), completionId)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.questTitle").value(QUEST_TITLE))
                .andExpect(jsonPath("$.data.photoUrls.length()").value(1))
                .andExpect(jsonPath("$.data.status").value("VOTING"))
                .andExpect(jsonPath("$.data.mine").value(true))
                .andReturn();

        // 좌표는 어떤 형태로도 응답에 실리지 않는다(docs/05 §3-5).
        assertThat(result.getResponse().getContentAsString())
                .doesNotContain("latitude")
                .doesNotContain("longitude");
    }

    @Test
    void 아직_인증을_올리지_않은_완료만_작성_후보에_남는다() throws Exception {
        Account author = signUp("candidate@proof.test", "후보모험가");
        long first = completeQuest(author);
        long second = completeQuest(author);

        createPost(author.token(), first).andExpect(status().isCreated());

        MvcResult result = mockMvc.perform(
                        org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                                .get("/api/quest-proofs/candidates")
                                .header("Authorization", "Bearer " + author.token()))
                .andExpect(status().isOk())
                .andReturn();

        String body = result.getResponse().getContentAsString();
        assertThat(JsonPath.<java.util.List<Integer>>read(body, "$.data[*].completionId"))
                .contains((int) second)
                .doesNotContain((int) first);
    }


    @Test
    void 삭제한_게시물의_완료_기록은_다시_쓸_수_없다() throws Exception {
        Account author = signUp("redo@proof.test", "재작성모험가");
        long completionId = completeQuest(author);

        MvcResult created = createPost(author.token(), completionId)
                .andExpect(status().isCreated())
                .andReturn();
        long postId = ((Number) JsonPath.read(
                created.getResponse().getContentAsString(), "$.data.postId")).longValue();

        mockMvc.perform(delete("/api/quest-proofs/{postId}", postId)
                        .header("Authorization", "Bearer " + author.token()))
                .andExpect(status().isOk());

        // 지웠다 다시 올릴 수 있으면 같은 완료 기록으로 투표 EXP를 반복 수확할 수 있다.
        createPost(author.token(), completionId)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("PROOF_ALREADY_POSTED"));

        // 후보 목록에도 돌아오지 않는다.
        MvcResult candidates = mockMvc.perform(get("/api/quest-proofs/candidates")
                        .header("Authorization", "Bearer " + author.token()))
                .andExpect(status().isOk())
                .andReturn();
        assertThat(JsonPath.<List<Integer>>read(
                candidates.getResponse().getContentAsString(), "$.data[*].completionId"))
                .doesNotContain((int) completionId);
    }

    @Test
    void 삭제한_게시물은_조회되지_않는다() throws Exception {
        Account author = signUp("gone@proof.test", "삭제모험가");
        long postId = createPostAndGetId(author);

        mockMvc.perform(delete("/api/quest-proofs/{postId}", postId)
                        .header("Authorization", "Bearer " + author.token()))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/quest-proofs/{postId}", postId)
                        .header("Authorization", "Bearer " + author.token()))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("PROOF_POST_NOT_FOUND"));
    }

    @Test
    void 설명이_컬럼_길이를_넘으면_400이다() throws Exception {
        Account author = signUp("long@proof.test", "장문모험가");
        long completionId = completeQuest(author);

        MockMultipartFile photo = new MockMultipartFile(
                "photos", "proof.jpg", MediaType.IMAGE_JPEG_VALUE, "fake-image-bytes".getBytes());

        // 검증이 없으면 DB 잘림 오류가 무결성 예외로 올라와 "이미 게시했습니다"(409)로 둔갑한다.
        mockMvc.perform(multipart("/api/quest-proofs")
                        .file(photo)
                        .param("completionId", String.valueOf(completionId))
                        .param("content", "가".repeat(501))
                        .header("Authorization", "Bearer " + author.token()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("PROOF_CONTENT_TOO_LONG"));
    }

    // --- 픽스처 ---

    private static final String QUEST_TITLE = "인증 광장 테스트 퀘스트";

    private record Account(String email, String token, long userId) {
    }

    private org.springframework.test.web.servlet.ResultActions createPost(
            String token, long completionId) throws Exception {

        MockMultipartFile photo = new MockMultipartFile(
                "photos", "proof.jpg", MediaType.IMAGE_JPEG_VALUE, "fake-image-bytes".getBytes());

        return mockMvc.perform(multipart("/api/quest-proofs")
                .file(photo)
                .param("completionId", String.valueOf(completionId))
                .param("content", "테스트 인증 게시물")
                .header("Authorization", "Bearer " + token));
    }

    private long createPostAndGetId(Account author) throws Exception {
        long completionId = completeQuest(author);
        MvcResult result = createPost(author.token(), completionId)
                .andExpect(status().isCreated())
                .andReturn();
        return ((Number) JsonPath.read(result.getResponse().getContentAsString(), "$.data.postId"))
                .longValue();
    }

    private org.springframework.test.web.servlet.ResultActions vote(
            String token, long postId, String choice) throws Exception {

        return mockMvc.perform(post("/api/quest-proofs/{postId}/votes", postId)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"choice\":\"%s\"}".formatted(choice)));
    }

    /** SELF_REPORT 퀘스트를 배정하고 완료해 완료 기록 ID를 돌려준다. */
    private long completeQuest(Account account) {
        User user = userRepository.findById(account.userId()).orElseThrow();

        Quest quest = questRepository.save(new Quest(
                QUEST_TITLE, "인증 광장 픽스처", QuestGrade.NORMAL, QuestCadence.DAILY,
                CompletionType.SELF_REPORT, 10,
                null, null, null, null, null,
                QuestCreator.SYSTEM, true));

        UserDailyQuest assignment = userDailyQuestRepository.save(new UserDailyQuest(
                user.getId(), quest.getId(), LocalDate.now(), LocalDateTime.now().plusDays(1)));

        return questCompletionService
                .complete(user.getId(), assignment.getId(), QuestCompletionRequest.empty())
                .completionId();
    }

    private Account signUp(String email, String nickname) throws Exception {
        mockMvc.perform(post("/api/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email": "%s", "password": "password123", "nickname": "%s"}
                                """.formatted(email, nickname)))
                .andExpect(status().isCreated());

        MvcResult login = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email": "%s", "password": "password123"}
                                """.formatted(email)))
                .andExpect(status().isOk())
                .andReturn();

        String token = JsonPath.read(login.getResponse().getContentAsString(), "$.data.accessToken");
        long userId = userRepository.findByEmailIgnoreCase(email).orElseThrow().getId();
        return new Account(email, token, userId);
    }
}
