package com.lifequest.proof.dto;

/** 게시물·댓글 작성자 요약. 피드에 필요한 최소 항목만 담는다. */
public record ProofAuthor(Long userId, String nickname, String profileImageUrl) {
}
