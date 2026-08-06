package com.lifequest.proof.dto;

import com.lifequest.proof.ProofVoteChoice;
import jakarta.validation.constraints.NotNull;

public record ProofVoteRequest(@NotNull ProofVoteChoice choice) {
}
