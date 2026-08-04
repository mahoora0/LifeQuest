package com.lifequest.user.dto;

import com.lifequest.profile.AvatarCharacter;

public record CharacterResponse(
        Long id,
        String code,
        String name,
        String assetKey,
        int requiredLevel,
        boolean unlocked) {
    public static CharacterResponse from(AvatarCharacter character) {
        return new CharacterResponse(
                character.getId(),
                character.getCode(),
                character.getName(),
                character.getAssetKey(),
                1,
                true);
    }

    public static CharacterResponse from(
            AvatarCharacter character, int requiredLevel, int userLevel) {
        return new CharacterResponse(
                character.getId(),
                character.getCode(),
                character.getName(),
                character.getAssetKey(),
                requiredLevel,
                userLevel >= requiredLevel);
    }
}
