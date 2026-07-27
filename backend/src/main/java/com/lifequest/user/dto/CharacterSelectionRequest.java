package com.lifequest.user.dto;

import jakarta.validation.constraints.NotNull;

public record CharacterSelectionRequest(@NotNull Long characterId) {
}
