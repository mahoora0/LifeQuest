package com.lifequest.proof;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.growth.ExpLogRepository;
import com.lifequest.growth.GrowthService;
import com.lifequest.proof.dto.ProofAuthor;
import com.lifequest.proof.dto.ProofCandidateResponse;
import com.lifequest.proof.dto.ProofCommentResponse;
import com.lifequest.proof.dto.ProofFeedResponse;
import com.lifequest.proof.dto.ProofPostResponse;
import com.lifequest.proof.dto.ProofVoteResponse;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.domain.QuestCompletion;
import com.lifequest.quest.repository.QuestCompletionRepository;
import com.lifequest.quest.repository.QuestRepository;
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

/**
 * 인증 광장. 퀘스트 완료 기록에 사진 게시물을 붙이고, 다른 사용자의 투표로 수행 여부를
 * 판정한다.
 *
 * <p><b>퀘스트 EXP는 이 서비스를 거치지 않는다.</b> 완료 시점에 이미 지급되어 있고
 * ({@code QuestCompletionServiceImpl}), 투표 결과가 그것을 회수하거나 보류시키지 않는다.
 * 투표로 지급을 게이트하면 완료 응답이 비동기가 되어 팀이 1주차에 합의한 완료 계약
 * ({@code docs/06-team-roles.md} §4)을 통째로 다시 짜야 하고, 사용자가 몇 명뿐인 환경에서는
 * 어떤 완료도 EXP를 받지 못한 채 멈춘다. 판정 결과는 배지로만 쓴다.
 */
@Service
@Transactional
public class QuestProofService {

    /** {@code ExpLog.sourceType}. 하루 지급 횟수를 이 값으로 센다. */
    private static final String VOTE_EXP_SOURCE = "PROOF_VOTE";

    /** 논리적 일자 경계. 퀘스트 배정·만료와 같은 04:00 기준을 쓴다({@code docs/05} §1-1). */
    private static final int DAY_BOUNDARY_HOUR = 4;

    private final QuestProofPostRepository postRepository;
    private final QuestProofPhotoRepository photoRepository;
    private final QuestProofVoteRepository voteRepository;
    private final QuestProofCommentRepository commentRepository;
    private final QuestCompletionRepository questCompletionRepository;
    private final QuestRepository questRepository;
    private final UserRepository userRepository;
    private final ExpLogRepository expLogRepository;
    private final GrowthService growthService;
    private final ProofImageStorage imageStorage;
    private final ProofSettings settings;
    private final Clock clock;

    public QuestProofService(
            QuestProofPostRepository postRepository,
            QuestProofPhotoRepository photoRepository,
            QuestProofVoteRepository voteRepository,
            QuestProofCommentRepository commentRepository,
            QuestCompletionRepository questCompletionRepository,
            QuestRepository questRepository,
            UserRepository userRepository,
            ExpLogRepository expLogRepository,
            GrowthService growthService,
            ProofImageStorage imageStorage,
            ProofSettings settings,
            Clock clock) {

        this.postRepository = postRepository;
        this.photoRepository = photoRepository;
        this.voteRepository = voteRepository;
        this.commentRepository = commentRepository;
        this.questCompletionRepository = questCompletionRepository;
        this.questRepository = questRepository;
        this.userRepository = userRepository;
        this.expLogRepository = expLogRepository;
        this.growthService = growthService;
        this.imageStorage = imageStorage;
        this.settings = settings;
        this.clock = clock;
    }

    /**
     * 완료 기록에 인증 게시물을 붙인다.
     *
     * <p>파일 저장이 트랜잭션 밖의 부수효과라는 점이 이 메서드의 유일한 까다로운 부분이다.
     * 게시물 저장이 실패하면 트랜잭션은 되돌아가지만 이미 쓴 파일은 남는다. 그래서 제약 위반을
     * 여기서 직접 받아 파일을 지운다 — {@code saveAndFlush}로 INSERT를 앞당기지 않으면 위반이
     * 커밋 시점에야 터져서 이 catch 밖으로 나간다.
     */
    public ProofPostResponse create(
            Long userId, Long completionId, String content, List<MultipartFile> photos) {

        if (photos == null || photos.isEmpty()) {
            throw new BusinessException(ErrorCode.PROOF_PHOTO_REQUIRED);
        }
        if (photos.size() > settings.maxPhotos()) {
            throw new BusinessException(ErrorCode.PROOF_PHOTO_LIMIT_EXCEEDED);
        }

        QuestCompletion completion = questCompletionRepository.findById(completionId)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
        // 남의 완료 기록인지 여부를 존재 여부와 구분해 알리지 않는다.
        if (!completion.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        }
        if (postRepository.existsByQuestCompletionId(completionId)) {
            throw new BusinessException(ErrorCode.PROOF_ALREADY_POSTED);
        }

        User author = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
        Quest quest = questRepository.findById(completion.getQuestId())
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));

        LocalDateTime now = LocalDateTime.now(clock);
        List<String> storedUrls = imageStorage.storeAll(photos);
        try {
            QuestProofPost post = new QuestProofPost(author, completionId, quest, normalize(content), now);
            storedUrls.forEach(post::addPhoto);
            postRepository.saveAndFlush(post);
            return toResponse(post, userId, storedUrls, null);
        } catch (DataIntegrityViolationException exception) {
            // 같은 완료 기록으로 동시에 두 요청이 들어온 경우. UNIQUE 제약이 최종 방어선이다.
            imageStorage.deleteAll(storedUrls);
            throw new BusinessException(ErrorCode.PROOF_ALREADY_POSTED);
        } catch (RuntimeException exception) {
            imageStorage.deleteAll(storedUrls);
            throw exception;
        }
    }

    @Transactional(readOnly = true)
    public ProofFeedResponse feed(Long userId, ProofFeedTab tab, Long cursor, int size) {
        int pageSize = clamp(size, 1, 30);
        Pageable pageable = PageRequest.of(0, pageSize);

        List<QuestProofPost> posts = switch (tab) {
            case NEEDS_VOTE -> postRepository.findNeedingVotes(userId, cursor, pageable);
            case ALL -> postRepository.findFeed(cursor, pageable);
            case MINE -> postRepository.findMine(userId, cursor, pageable);
        };

        List<ProofPostResponse> items = toResponses(posts, userId);
        // 요청한 만큼 채워졌을 때만 커서를 준다. 덜 채워졌으면 다음 페이지가 없다.
        Long nextCursor = items.size() < pageSize ? null : posts.get(posts.size() - 1).getId();
        return new ProofFeedResponse(items, nextCursor);
    }

    @Transactional(readOnly = true)
    public ProofPostResponse detail(Long userId, Long postId) {
        QuestProofPost post = postRepository.findDetailById(postId)
                .orElseThrow(() -> new BusinessException(ErrorCode.PROOF_POST_NOT_FOUND));
        return toResponses(List.of(post), userId).get(0);
    }

    @Transactional(readOnly = true)
    public List<ProofCandidateResponse> postableCompletions(Long userId, int size) {
        return postRepository.findPostableCompletions(
                userId, PageRequest.of(0, clamp(size, 1, 50)));
    }

    /**
     * 투표한다. 같은 트랜잭션에서 표를 더하고, 판정을 다시 계산하고, EXP를 지급한다.
     *
     * <p>맨 앞의 사용자 행 잠금이 하루 EXP 한도를 지킨다. 한도 검사는 지급 이력을 세는 방식이라,
     * 같은 사용자의 투표 두 건이 동시에 들어오면 둘 다 검사를 통과한 뒤 각자 지급해 한도를
     * 넘길 수 있다. {@code GrowthService.grantExp}가 어차피 잡을 잠금을 앞당겨 잡으면 같은
     * 사용자의 투표가 직렬화되어 그 창이 사라진다.
     */
    public ProofVoteResponse vote(Long userId, Long postId, ProofVoteChoice choice) {
        QuestProofPost post = postRepository.findDetailById(postId)
                .orElseThrow(() -> new BusinessException(ErrorCode.PROOF_POST_NOT_FOUND));
        if (post.isAuthor(userId)) {
            throw new BusinessException(ErrorCode.CANNOT_VOTE_OWN_PROOF);
        }
        if (voteRepository.existsByPost_IdAndVoter_Id(postId, userId)) {
            throw new BusinessException(ErrorCode.PROOF_ALREADY_VOTED);
        }

        User voter = userRepository.findByIdForUpdate(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));

        LocalDateTime now = LocalDateTime.now(clock);
        try {
            voteRepository.saveAndFlush(new QuestProofVote(post, voter, choice, now));
        } catch (DataIntegrityViolationException exception) {
            throw new BusinessException(ErrorCode.PROOF_ALREADY_VOTED);
        }

        post.applyVote(choice, settings, now);
        int expGained = grantVoteExp(userId, postId, now);

        return new ProofVoteResponse(
                toResponses(List.of(post), userId).get(0), expGained);
    }

    @Transactional(readOnly = true)
    public List<ProofCommentResponse> comments(Long userId, Long postId) {
        if (!postRepository.existsById(postId)) {
            throw new BusinessException(ErrorCode.PROOF_POST_NOT_FOUND);
        }
        return commentRepository.findByPostId(postId).stream()
                .map(comment -> new ProofCommentResponse(
                        comment.getId(),
                        toAuthor(comment.getAuthor()),
                        comment.getContent(),
                        comment.isAuthor(userId),
                        comment.getCreatedAt()))
                .toList();
    }

    public ProofCommentResponse addComment(Long userId, Long postId, String content) {
        QuestProofPost post = postRepository.findById(postId)
                .orElseThrow(() -> new BusinessException(ErrorCode.PROOF_POST_NOT_FOUND));
        User author = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));

        LocalDateTime now = LocalDateTime.now(clock);
        QuestProofComment comment = commentRepository.save(
                new QuestProofComment(post, author, content.strip(), now));
        post.addComment(now);

        return new ProofCommentResponse(
                comment.getId(), toAuthor(author), comment.getContent(), true, comment.getCreatedAt());
    }

    /**
     * 게시물을 지운다. 투표·댓글도 함께 사라지므로 이미 지급된 투표 EXP는 회수하지 않는다 —
     * 회수하면 남이 글을 지웠다는 이유로 내 레벨이 내려간다.
     */
    public void delete(Long userId, Long postId) {
        QuestProofPost post = postRepository.findById(postId)
                .orElseThrow(() -> new BusinessException(ErrorCode.PROOF_POST_NOT_FOUND));
        if (!post.isAuthor(userId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }

        List<String> imageUrls = post.getPhotos().stream()
                .map(QuestProofPhoto::getImageUrl)
                .toList();

        commentRepository.deleteByPost_Id(postId);
        voteRepository.deleteByPost_Id(postId);
        postRepository.delete(post);
        postRepository.flush();

        // DB에서 지워진 것이 확정된 뒤에 파일을 지운다. 순서를 뒤집으면 삭제가 실패해
        // 롤백됐을 때 게시물은 남고 사진만 사라진다.
        imageStorage.deleteAll(imageUrls);
    }

    private int grantVoteExp(Long userId, Long postId, LocalDateTime now) {
        if (settings.voteExp() <= 0 || settings.dailyVoteExpGrants() <= 0) {
            return 0;
        }

        long granted = expLogRepository.countByUserIdAndSourceTypeAndCreatedAtGreaterThanEqual(
                userId, VOTE_EXP_SOURCE, logicalDayStart(now));
        if (granted >= settings.dailyVoteExpGrants()) {
            return 0;
        }

        // sourceId를 게시물 ID로 두면 GrowthService의 (사용자, 출처, 출처 ID) 멱등성이
        // 게시물당 1회 지급을 그대로 보장한다.
        return growthService.grantExp(userId, VOTE_EXP_SOURCE, postId, settings.voteExp())
                .expGained();
    }

    /** 04:00 경계 기준 오늘의 시작. 02:00의 "오늘"은 어제 04:00부터다. */
    private Instant logicalDayStart(LocalDateTime now) {
        return now.minusHours(DAY_BOUNDARY_HOUR)
                .toLocalDate()
                .atTime(DAY_BOUNDARY_HOUR, 0)
                .atZone(clock.getZone())
                .toInstant();
    }

    private List<ProofPostResponse> toResponses(List<QuestProofPost> posts, Long userId) {
        if (posts.isEmpty()) {
            return List.of();
        }

        List<Long> postIds = posts.stream().map(QuestProofPost::getId).toList();
        Map<Long, List<String>> photosByPost = photoUrlsByPost(postIds);
        Map<Long, ProofVoteChoice> myVotes = voteRepository
                .findByVoter_IdAndPost_IdIn(userId, postIds).stream()
                .collect(Collectors.toMap(QuestProofVote::getPostId, QuestProofVote::getChoice));

        return posts.stream()
                .map(post -> toResponse(
                        post,
                        userId,
                        photosByPost.getOrDefault(post.getId(), List.of()),
                        myVotes.get(post.getId())))
                .toList();
    }

    private Map<Long, List<String>> photoUrlsByPost(Collection<Long> postIds) {
        Map<Long, List<String>> byPost = new HashMap<>();
        for (QuestProofPhoto photo : photoRepository.findByPostIds(postIds)) {
            byPost.computeIfAbsent(photo.getPostId(), key -> new ArrayList<>())
                    .add(photo.getImageUrl());
        }
        return byPost;
    }

    private ProofPostResponse toResponse(
            QuestProofPost post, Long userId, List<String> photoUrls, ProofVoteChoice myVote) {

        return new ProofPostResponse(
                post.getId(),
                toAuthor(post.getAuthor()),
                post.getQuest().getId(),
                post.getQuest().getTitle(),
                post.getQuest().getGrade(),
                post.getContent(),
                photoUrls,
                post.getStatus(),
                post.getAgreeCount(),
                post.getUnsureCount(),
                post.getRejectCount(),
                post.decidedVoteCount(),
                settings.minVotes(),
                post.getCommentCount(),
                myVote,
                post.isAuthor(userId),
                post.getCreatedAt());
    }

    private static ProofAuthor toAuthor(User user) {
        return new ProofAuthor(user.getId(), user.getNickname(), user.getProfileImageUrl());
    }

    /** Java 17 대상이라 {@code Math.clamp}(21)를 쓸 수 없다. */
    private static int clamp(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }

    private static String normalize(String content) {
        if (content == null) {
            return null;
        }
        String stripped = content.strip();
        return stripped.isEmpty() ? null : stripped;
    }
}
