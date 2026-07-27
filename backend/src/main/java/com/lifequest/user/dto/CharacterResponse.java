package com.lifequest.user.dto;

import com.lifequest.profile.AvatarCharacter;

public record CharacterResponse(Long id, String code, String name, String assetKey) {
    public static CharacterResponse from(AvatarCharacter character) {
        return new CharacterResponse(
                character.getId(),
                character.getCode(),
                character.getName(),
                character.getAssetKey());
    }
}
