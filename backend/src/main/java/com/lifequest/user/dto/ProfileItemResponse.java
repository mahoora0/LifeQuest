package com.lifequest.user.dto;

import com.lifequest.profile.ProfileItem;
import com.lifequest.profile.UserProfileItem;
import java.time.Instant;

public record ProfileItemResponse(
        Long id,
        String name,
        String itemType,
        String sourceType,
        Instant acquiredAt) {

    public static ProfileItemResponse from(ProfileItem item) {
        return new ProfileItemResponse(
                item.getId(), item.getName(), item.getItemType().name(), null, null);
    }

    public static ProfileItemResponse from(UserProfileItem owned) {
        ProfileItem item = owned.getProfileItem();
        return new ProfileItemResponse(
                item.getId(),
                item.getName(),
                item.getItemType().name(),
                owned.getSourceType(),
                owned.getAcquiredAt());
    }
}
