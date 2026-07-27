package com.lifequest.user.dto;

import java.util.List;

public record RewardHistoryResponse(
        List<TitleResponse> titles,
        List<ProfileItemResponse> profileItems) {
}
