package com.lifequest.user;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.user.dto.UpdateProfileRequest;
import com.lifequest.user.dto.UserProfileResponse;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserService {

    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Transactional(readOnly = true)
    public UserProfileResponse getProfile(Long userId) {
        return UserProfileResponse.from(getUser(userId));
    }

    @Transactional
    public UserProfileResponse updateProfile(Long userId, UpdateProfileRequest request) {
        User user = getUser(userId);
        String nickname = request.nickname() == null ? user.getNickname() : request.nickname();
        if (!nickname.equals(user.getNickname())
                && userRepository.existsByNicknameAndIdNot(nickname, userId)) {
            throw new BusinessException(ErrorCode.DUPLICATE_NICKNAME);
        }

        String imageUrl = request.profileImageUrl() == null
                ? user.getProfileImageUrl()
                : normalizeImageUrl(request.profileImageUrl());
        user.updateProfile(nickname, imageUrl);
        return UserProfileResponse.from(user);
    }

    @Transactional(readOnly = true)
    public Map<String, Integer> getLevel(Long userId) {
        User user = getUser(userId);
        int requiredPerLevel = 100;
        return Map.of(
                "level", user.getLevel(),
                "totalExp", user.getTotalExp(),
                "currentLevelExp", user.getTotalExp() % requiredPerLevel,
                "nextLevelRequiredExp", requiredPerLevel);
    }

    private User getUser(Long id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
    }

    private String normalizeImageUrl(String value) {
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}
