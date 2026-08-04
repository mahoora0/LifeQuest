package com.lifequest.social.dto;

import jakarta.validation.constraints.NotNull;

// 친구 요청을 보내기 위한 DTO
public record SendFriendRequestRequest(
                @NotNull(message = "친구 요청을 받을 사용자를 선택해 주세요.") Long receiverId) {
}
