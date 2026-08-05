package com.lifequest.user.dto;

import com.lifequest.user.User;

public record UserProfileResponse(
        Long id,
        String email,
        String nickname,
        String profileImageUrl,
        String role,
        TitleResponse representativeTitle,
        ProfileItemResponse representativeBadge,
        CharacterResponse selectedCharacter,
        AccessoryResponse selectedAccessory) {

    public static UserProfileResponse from(User user) {
        return new UserProfileResponse(
                user.getId(),
                user.getEmail(),
                user.getNickname(),
                user.getProfileImageUrl(),
                user.getRole().name(),
                user.getRepresentativeTitle() == null
                        ? null
                        : TitleResponse.from(user.getRepresentativeTitle()),
                user.getRepresentativeBadge() == null
                        ? null
                        : ProfileItemResponse.from(user.getRepresentativeBadge()),
                user.getSelectedCharacter() == null
                        ? null
                        : CharacterResponse.from(user.getSelectedCharacter()),
                user.getSelectedAccessory() == null
                        ? null
                        : AccessoryResponse.selected(user.getSelectedAccessory()));
    }
}
