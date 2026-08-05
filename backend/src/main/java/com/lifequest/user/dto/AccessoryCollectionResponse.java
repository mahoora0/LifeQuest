package com.lifequest.user.dto;

import java.util.List;

public record AccessoryCollectionResponse(
        List<AccessoryResponse> accessories,
        Long selectedAccessoryId) {
}
