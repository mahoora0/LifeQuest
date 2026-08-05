package com.lifequest.user.dto;

import com.lifequest.profile.ProfileItem;

public record AccessoryResponse(
        Long id,
        String code,
        String name,
        Integer requiredLevel,
        boolean unlocked) {

    public static AccessoryResponse from(
            ProfileItem item, Integer requiredLevel, boolean unlocked) {
        return new AccessoryResponse(
                item.getId(),
                item.getCode(),
                item.getName(),
                requiredLevel,
                unlocked);
    }

    public static AccessoryResponse selected(ProfileItem item) {
        return new AccessoryResponse(
                item.getId(), item.getCode(), item.getName(), null, true);
    }
}
