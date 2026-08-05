package com.lifequest.group.dto;
import jakarta.validation.constraints.NotNull;
public record InviteGroupMemberRequest(@NotNull Long userId) {}
