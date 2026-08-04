package com.lifequest.social.dto;

import jakarta.validation.constraints.NotNull;

// 친구 요청 처리 요청을 나타내는 DTO
public record RespondFriendRequestRequest(
                @NotNull(message = "친구 요청 처리 방식을 선택해 주세요.") FriendRequestAction action) {
}
