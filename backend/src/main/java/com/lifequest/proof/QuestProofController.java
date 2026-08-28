package com.lifequest.proof;

import com.lifequest.common.response.ApiResponse;
import com.lifequest.proof.dto.ProofCandidateResponse;
import com.lifequest.proof.dto.ProofCommentRequest;
import com.lifequest.proof.dto.ProofCommentResponse;
import com.lifequest.proof.dto.ProofFeedResponse;
import com.lifequest.proof.dto.ProofPostResponse;
import com.lifequest.proof.dto.ProofVoteRequest;
import com.lifequest.proof.dto.ProofVoteResponse;
import com.lifequest.quest.domain.QuestCategory;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/** 인증 광장 엔드포인트. */
@RestController
@RequestMapping("/api/quest-proofs")
public class QuestProofController {

    private final QuestProofService questProofService;

    public QuestProofController(QuestProofService questProofService) {
        this.questProofService = questProofService;
    }

    /**
     * 인증 게시물 등록.
     *
     * <p>퀘스트를 받지 않고 완료 기록 ID만 받는다. 퀘스트명은 그 기록에서 따라오므로 사용자가
     * 수행하지 않은 퀘스트를 붙일 경로가 없다.
     */
    @PostMapping(consumes = "multipart/form-data")
    public ResponseEntity<ApiResponse<ProofPostResponse>> create(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam Long completionId,
            @RequestParam(required = false) String content,
            @RequestPart("photos") List<MultipartFile> photos) {

        ProofPostResponse response = questProofService.create(
                userId(jwt), completionId, content, photos);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.success(response));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<ProofFeedResponse>> feed(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "NEEDS_VOTE") ProofFeedTab tab,
            @RequestParam(required = false) QuestCategory category,
            @RequestParam(required = false) Long cursor,
            @RequestParam(defaultValue = "10") int size) {

        return ResponseEntity.ok(ApiResponse.success(
                questProofService.feed(userId(jwt), tab, category, cursor, size)));
    }

    /** 작성 화면의 퀘스트 선택 목록 — 아직 인증을 올리지 않은 내 완료 기록. */
    @GetMapping("/candidates")
    public ResponseEntity<ApiResponse<List<ProofCandidateResponse>>> candidates(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "20") int size) {

        return ResponseEntity.ok(ApiResponse.success(
                questProofService.postableCompletions(userId(jwt), size)));
    }

    @GetMapping("/{postId}")
    public ResponseEntity<ApiResponse<ProofPostResponse>> detail(
            @AuthenticationPrincipal Jwt jwt, @PathVariable Long postId) {

        return ResponseEntity.ok(ApiResponse.success(
                questProofService.detail(userId(jwt), postId)));
    }

    @DeleteMapping("/{postId}")
    public ResponseEntity<ApiResponse<Void>> delete(
            @AuthenticationPrincipal Jwt jwt, @PathVariable Long postId) {

        questProofService.delete(userId(jwt), postId);
        return ResponseEntity.ok(ApiResponse.success(null));
    }

    @PostMapping("/{postId}/votes")
    public ResponseEntity<ApiResponse<ProofVoteResponse>> vote(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long postId,
            @Valid @RequestBody ProofVoteRequest request) {

        return ResponseEntity.ok(ApiResponse.success(
                questProofService.vote(userId(jwt), postId, request.choice())));
    }

    @GetMapping("/{postId}/comments")
    public ResponseEntity<ApiResponse<List<ProofCommentResponse>>> comments(
            @AuthenticationPrincipal Jwt jwt, @PathVariable Long postId) {

        return ResponseEntity.ok(ApiResponse.success(
                questProofService.comments(userId(jwt), postId)));
    }

    @PostMapping("/{postId}/comments")
    public ResponseEntity<ApiResponse<ProofCommentResponse>> addComment(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long postId,
            @Valid @RequestBody ProofCommentRequest request) {

        ProofCommentResponse response = questProofService.addComment(
                userId(jwt), postId, request.content());
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.success(response));
    }

    private static Long userId(Jwt jwt) {
        return Long.valueOf(jwt.getSubject());
    }
}
