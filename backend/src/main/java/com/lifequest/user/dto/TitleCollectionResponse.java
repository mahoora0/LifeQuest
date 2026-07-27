package com.lifequest.user.dto;

import java.util.List;

public record TitleCollectionResponse(
        List<TitleResponse> titles,
        Long representativeTitleId) {
}
