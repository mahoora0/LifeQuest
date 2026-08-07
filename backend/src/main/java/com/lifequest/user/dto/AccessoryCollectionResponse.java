package com.lifequest.user.dto;

import java.util.List;
import java.util.Map;

public record AccessoryCollectionResponse(
        List<AccessoryResponse> accessories,
        Long selectedAccessoryId,
        Map<Long, Long> selectedAccessoryIdsByCharacter) {
}
