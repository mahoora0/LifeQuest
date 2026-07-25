package com.lifequest.user.dto;

import java.util.List;

public record BadgeCollectionResponse(
        List<ProfileItemResponse> badges,
        Long representativeBadgeId) {
}
