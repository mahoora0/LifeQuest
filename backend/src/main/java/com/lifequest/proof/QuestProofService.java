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
import java.util.Locale;
import java.util.Map;
import java.util.stream.Collectors;
import org.hibernate.exception.ConstraintViolationException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;

import static org.springframework.transaction.annotation.Isolation.READ_COMMITTED;

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

    /** {@code quest_proof_posts.content}의 컬럼 길이. 검증을 DB보다 앞에서 한다. */
    private static final int MAX_CONTENT_LENGTH = 500;

    /** V13에서 붙인 제약 이름. 무결성 위반의 원인을 좁히는 데 쓴다. */
    private static final String COMPLETION_UNIQUE_CONSTRAINT = "uk_quest_proof_posts_completion";
    private static final String VOTER_UNIQUE_CONSTRAINT = "uk_quest_proof_votes_voter";

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
     * 저장한 파일은 트랜잭션이 되돌아가도 디스크에 남으므로 롤백 콜백으로 지운다. 이 메서드
     * 안에서 {@code catch}로 지우면 부족하다 — 커밋은 메서드가 끝난 뒤 트랜잭션 프록시에서
     * 일어나므로, 커밋 단계에서 실패하면 어떤 {@code catch}도 실행되지 않고 파일만 남는다.
     */
    public ProofPostResponse create(
            Long userId, Long completionId, String content, List<MultipartFile> photos) {

        if (photos == null || photos.isEmpty()) {
            throw new BusinessException(ErrorCode.PROOF_PHOTO_REQUIRED);
        }
        if (photos.size() > settings.maxPhotos()) {
            throw new BusinessException(ErrorCode.PROOF_PHOTO_LIMIT_EXCEEDED);
        }
        String normalizedContent = normalize(content);
        // 컬럼 길이(VARCHAR 500)에 기대지 않고 여기서 막는다. DB까지 내려보내면 잘림 오류가
        // 무결성 예외로 올라와 아래 중복 판정과 섞인다 — 파일을 쓰기 전이라는 점도 중요하다.
        if (normalizedContent != null && normalizedContent.length() > MAX_CONTENT_LENGTH) {
            throw new BusinessException(ErrorCode.PROOF_CONTENT_TOO_LONG);
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
        deleteFilesOnRollback(storedUrls);

        try {
            QuestProofPost post =
                    new QuestProofPost(author, completionId, quest, normalizedContent, now);
            storedUrls.forEach(post::addPhoto);
            postRepository.saveAndFlush(post);
            return toResponse(post, userId, storedUrls, null);
        } catch (DataIntegrityViolationException exception) {
            // 같은 완료 기록으로 동시에 두 요청이 들어온 경우에만 중복으로 바꾼다. 어떤 무결성
            // 위반이든 "이미 게시했습니다"로 덮으면 진짜 원인이 응답에서도 로그에서도 사라진다.
            if (violates(exception, COMPLETION_UNIQUE_CONSTRAINT)) {
                throw new BusinessException(ErrorCode.PROOF_ALREADY_POSTED);
            }
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
     * <p>잠금을 두 개 잡고, <b>순서가 규칙</b>이다 — 사용자 행이 먼저, 게시물 행이 나중.
     *
     * <p>사용자 행이 첫 DB 접근이어야 하는 이유는 격리 수준 때문이다. 하루 EXP 한도는 지급
     * 이력을 세어 판정하는데, MySQL의 기본 REPEATABLE READ에서는 트랜잭션의 <b>첫 평범한
     * SELECT</b>가 만든 스냅샷을 이후의 평범한 조회가 계속 쓴다. 잠금을 잡기 전에 아무 조회나
     * 먼저 하면, 잠금을 얻은 뒤에 세는 이력에서 앞선 트랜잭션이 방금 넣은 지급 기록이 보이지
     * 않아 한도를 넘길 수 있다. 이 메서드를 READ_COMMITTED로 두는 것으로도 막히지만, 잠금을
     * 앞으로 옮기면 격리 수준에 기대지 않아도 된다 — 둘 다 한다.
     *
     * <p>게시물 행을 잠그는 이유는 표 카운터가 엔티티 필드 증가로 갱신되기 때문이다. 잠그지
     * 않으면 동시 투표 두 건이 같은 값을 읽고 같은 값을 써서 한 표가 사라진다.
     */
    @Transactional(isolation = READ_COMMITTED)
    public ProofVoteResponse vote(Long userId, Long postId, ProofVoteChoice choice) {
        User voter = userRepository.findByIdForUpdate(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
        QuestProofPost post = postRepository.findByIdForUpdate(postId)
                .orElseThrow(() -> new BusinessException(ErrorCode.PROOF_POST_NOT_FOUND));

        if (post.isAuthor(userId)) {
            throw new BusinessException(ErrorCode.CANNOT_VOTE_OWN_PROOF);
        }
        if (voteRepository.existsByPost_IdAndVoter_Id(postId, userId)) {
            throw new BusinessException(ErrorCode.PROOF_ALREADY_VOTED);
        }

        LocalDateTime now = LocalDateTime.now(clock);
        try {
            voteRepository.saveAndFlush(new QuestProofVote(post, voter, choice, now));
        } catch (DataIntegrityViolationException exception) {
            if (violates(exception, VOTER_UNIQUE_CONSTRAINT)) {
                throw new BusinessException(ErrorCode.PROOF_ALREADY_VOTED);
            }
            throw exception;
        }

        post.applyVote(choice, settings, now);
        int expGained = grantVoteExp(userId, postId, now);

        return new ProofVoteResponse(
                toResponses(List.of(post), userId).get(0), expGained);
    }

    @Transactional(readOnly = true)
    public List<ProofCommentResponse> comments(Long userId, Long postId) {
        // existsById로는 부족하다 — 삭제된 게시물의 행은 남아 있으므로 참을 돌려준다.
        if (postRepository.findDetailById(postId).isEmpty()) {
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

    /** 댓글 수도 엔티티 필드 증가라 {@link #vote}와 같은 이유로 게시물 행을 잠근다. */
    public ProofCommentResponse addComment(Long userId, Long postId, String content) {
        QuestProofPost post = postRepository.findByIdForUpdate(postId)
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
     * 게시물을 지운다. 행은 남기고 삭제 표시만 한다 — 지워 버리면
     * {@code UNIQUE(quest_completion_id)}가 함께 사라져 같은 완료 기록으로 다시 올릴 수 있고,
     * 그 경로로 투표 EXP를 반복해서 받을 수 있다(V14 주석).
     *
     * <p>이미 지급된 투표 EXP는 회수하지 않는다 — 회수하면 남이 글을 지웠다는 이유로 내
     * 레벨이 내려간다. 투표·댓글 행도 남긴다. 게시물 행이 남아 있어 참조가 깨지지 않고,
     * 지워 봐야 되돌릴 수 없는 판정 이력만 잃는다.
     */
    public void delete(Long userId, Long postId) {
        QuestProofPost post = postRepository.findByIdForUpdate(postId)
                .orElseThrow(() -> new BusinessException(ErrorCode.PROOF_POST_NOT_FOUND));
        if (!post.isAuthor(userId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }

        // 파일 정리는 커밋 이후로 미룬다. flush는 커밋이 아니라서, 여기서 지우면 이후 커밋이
        // 실패했을 때 게시물은 되살아나고 사진만 사라진다.
        deleteFilesAfterCommit(post.markDeleted(LocalDateTime.now(clock)));
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

    /**
     * 트랜잭션이 커밋된 뒤에 파일을 지운다. 커밋 전에 지우면 이후 커밋 실패나 바깥
     * 트랜잭션의 롤백으로 DB 상태만 되살아나고 사진은 사라진다.
     */
    private void deleteFilesAfterCommit(List<String> imageUrls) {
        if (imageUrls.isEmpty()) {
            return;
        }
        if (!TransactionSynchronizationManager.isSynchronizationActive()) {
            imageStorage.deleteAll(imageUrls);
            return;
        }
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                imageStorage.deleteAll(imageUrls);
            }
        });
    }

    /**
     * 트랜잭션이 되돌아가면 저장했던 파일을 지운다. {@code catch}로는 부족하다 — 커밋은 이
     * 서비스 메서드가 끝난 뒤 트랜잭션 프록시에서 일어나므로, 커밋 단계에서 실패하면 메서드
     * 안의 어떤 {@code catch}도 실행되지 않는다.
     */
    private void deleteFilesOnRollback(List<String> imageUrls) {
        if (imageUrls.isEmpty() || !TransactionSynchronizationManager.isSynchronizationActive()) {
            return;
        }
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCompletion(int status) {
                if (status == STATUS_ROLLED_BACK) {
                    imageStorage.deleteAll(imageUrls);
                }
            }
        });
    }

    /**
     * 무결성 위반이 지목된 제약에서 났는지 본다.
     *
     * <p>제약 이름으로 판별하는 이유는, 위반이 난 뒤에는 영속성 컨텍스트가 롤백 대상으로
     * 표시되어 확인용 질의를 다시 던질 수 없기 때문이다. 이름이 비어 오는 드라이버가 있어
     * 메시지 본문까지 함께 본다.
     */
    private static boolean violates(DataIntegrityViolationException exception, String constraint) {
        for (Throwable cause = exception; cause != null; cause = cause.getCause()) {
            if (cause instanceof ConstraintViolationException violation) {
                String name = violation.getConstraintName();
                if (name != null && name.toLowerCase(Locale.ROOT).contains(constraint)) {
                    return true;
                }
            }
            String message = cause.getMessage();
            if (message != null && message.toLowerCase(Locale.ROOT).contains(constraint)) {
                return true;
            }
        }
        return false;
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
