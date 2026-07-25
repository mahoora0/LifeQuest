package com.lifequest.user.dto;

import com.lifequest.profile.Title;
import com.lifequest.profile.UserTitle;
import java.time.Instant;

public record TitleResponse(
        Long id,
        String name,
        String description,
        String sourceType,
        Instant acquiredAt) {

    public static TitleResponse from(Title title) {
        return new TitleResponse(
                title.getId(), title.getName(), title.getDescription(), null, null);
    }

    public static TitleResponse from(UserTitle owned) {
        Title title = owned.getTitle();
        return new TitleResponse(
                title.getId(),
                title.getName(),
                title.getDescription(),
                owned.getSourceType(),
                owned.getAcquiredAt());
    }
}
