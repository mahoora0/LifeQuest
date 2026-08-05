package com.lifequest.group.dto;
import jakarta.validation.constraints.NotNull;
public record TransferGroupOwnerRequest(@NotNull Long newOwnerUserId) {}
