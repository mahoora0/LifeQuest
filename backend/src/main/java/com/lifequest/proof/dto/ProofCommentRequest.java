package com.lifequest.proof.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ProofCommentRequest(@NotBlank @Size(max = 500) String content) {
}
