package com.lifequest.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record ReissueRequest(@NotBlank String refreshToken) {
}
