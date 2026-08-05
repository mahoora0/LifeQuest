package com.lifequest.proof.dto;

import java.time.LocalDateTime;

public record ProofCommentResponse(
        Long commentId,
        ProofAuthor author,
        String content,
        boolean mine,
        LocalDateTime createdAt) {
}
