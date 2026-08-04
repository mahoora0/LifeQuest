package com.lifequest.user;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.user.dto.UpdateProfileRequest;
import com.lifequest.user.dto.BadgeCollectionResponse;
import com.lifequest.user.dto.CharacterResponse;
import com.lifequest.user.dto.ProfileItemResponse;
import com.lifequest.user.dto.RewardHistoryResponse;
import com.lifequest.user.dto.TitleCollectionResponse;
import com.lifequest.user.dto.TitleResponse;
import com.lifequest.user.dto.UserProfileResponse;
import com.lifequest.growth.GrowthService;
import com.lifequest.profile.AvatarCharacter;
import com.lifequest.profile.AvatarCharacterRepository;
import com.lifequest.profile.ProfileItem;
import com.lifequest.profile.ProfileImageStorage;
import com.lifequest.profile.UserProfileItem;
import com.lifequest.profile.UserProfileItemRepository;
import com.lifequest.profile.UserTitle;
import com.lifequest.profile.UserTitleRepository;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final AvatarCharacterRepository characterRepository;
    private final UserTitleRepository userTitleRepository;
    private final UserProfileItemRepository userProfileItemRepository;
    private final ProfileImageStorage profileImageStorage;

    public UserService(
            UserRepository userRepository,
            AvatarCharacterRepository characterRepository,
            UserTitleRepository userTitleRepository,
            UserProfileItemRepository userProfileItemRepository,
            ProfileImageStorage profileImageStorage) {
        this.userRepository = userRepository;
        this.characterRepository = characterRepository;
        this.userTitleRepository = userTitleRepository;
        this.userProfileItemRepository = userProfileItemRepository;
        this.profileImageStorage = profileImageStorage;
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

        user.updateProfile(nickname, user.getProfileImageUrl());
        return UserProfileResponse.from(user);
    }

    @Transactional(readOnly = true)
    public Map<String, Integer> getLevel(Long userId) {
        User user = getUser(userId);
        int levelStartExp = GrowthService.cumulativeExpForLevel(user.getLevel());
        int requiredExp = GrowthService.requiredExpForNextLevel(user.getLevel());
        return Map.of(
                "level", user.getLevel(),
                "totalExp", user.getTotalExp(),
                "currentLevelExp", user.getTotalExp() - levelStartExp,
                "nextLevelRequiredExp", requiredExp);
    }

    @Transactional(readOnly = true)
    public List<CharacterResponse> getCharacters(Long userId) {
        User user = getUser(userId);
        List<AvatarCharacter> characters =
                characterRepository.findAllByActiveTrueOrderById();
        return java.util.stream.IntStream.range(0, characters.size())
                .mapToObj(index -> CharacterResponse.from(
                        characters.get(index), requiredLevel(index), user.getLevel()))
                .toList();
    }

    @Transactional
    public UserProfileResponse selectCharacter(Long userId, Long characterId) {
        User user = getUser(userId);
        AvatarCharacter character = characterRepository.findById(characterId)
                .filter(AvatarCharacter::isActive)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
        List<AvatarCharacter> characters =
                characterRepository.findAllByActiveTrueOrderById();
        int index = characters.indexOf(character);
        if (index < 0 || user.getLevel() < requiredLevel(index)) {
            throw new BusinessException(ErrorCode.CHARACTER_LOCKED);
        }
        user.selectCharacter(character);
        return UserProfileResponse.from(user);
    }

    @Transactional(readOnly = true)
    public TitleCollectionResponse getTitles(Long userId) {
        User user = getUser(userId);
        List<TitleResponse> titles = userTitleRepository
                .findAllByUserIdOrderByAcquiredAtDesc(userId).stream()
                .map(TitleResponse::from)
                .toList();
        return new TitleCollectionResponse(
                titles,
                user.getRepresentativeTitle() == null
                        ? null
                        : user.getRepresentativeTitle().getId());
    }

    @Transactional
    public UserProfileResponse selectRepresentativeTitle(Long userId, Long titleId) {
        User user = getUser(userId);
        if (titleId == null) {
            user.selectRepresentativeTitle(null);
        } else {
            UserTitle owned = userTitleRepository.findByUserIdAndTitleId(userId, titleId)
                    .orElseThrow(() -> new BusinessException(ErrorCode.FORBIDDEN));
            user.selectRepresentativeTitle(owned.getTitle());
        }
        return UserProfileResponse.from(user);
    }

    @Transactional(readOnly = true)
    public BadgeCollectionResponse getBadges(Long userId) {
        User user = getUser(userId);
        List<ProfileItemResponse> badges = userProfileItemRepository
                .findAllByUserIdOrderByAcquiredAtDesc(userId).stream()
                .filter(owned -> owned.getProfileItem().getItemType()
                        == ProfileItem.ItemType.BADGE)
                .map(ProfileItemResponse::from)
                .toList();
        return new BadgeCollectionResponse(
                badges,
                user.getRepresentativeBadge() == null
                        ? null
                        : user.getRepresentativeBadge().getId());
    }

    @Transactional
    public UserProfileResponse selectRepresentativeBadge(Long userId, Long badgeId) {
        User user = getUser(userId);
        if (badgeId == null) {
            user.selectRepresentativeBadge(null);
        } else {
            UserProfileItem owned =
                    userProfileItemRepository.findByUserIdAndProfileItemId(userId, badgeId)
                            .filter(item -> item.getProfileItem().getItemType()
                                    == ProfileItem.ItemType.BADGE)
                            .orElseThrow(() -> new BusinessException(ErrorCode.FORBIDDEN));
            user.selectRepresentativeBadge(owned.getProfileItem());
        }
        return UserProfileResponse.from(user);
    }

    @Transactional(readOnly = true)
    public RewardHistoryResponse getRewards(Long userId) {
        getUser(userId);
        return new RewardHistoryResponse(
                userTitleRepository.findAllByUserIdOrderByAcquiredAtDesc(userId).stream()
                        .map(TitleResponse::from)
                        .toList(),
                userProfileItemRepository.findAllByUserIdOrderByAcquiredAtDesc(userId).stream()
                        .map(ProfileItemResponse::from)
                        .toList());
    }

    @Transactional
    public UserProfileResponse uploadProfileImage(Long userId, MultipartFile file) {
        User user = getUser(userId);
        String previousImageUrl = user.getProfileImageUrl();
        String imageUrl = profileImageStorage.store(file);
        user.updateProfileImage(imageUrl);
        profileImageStorage.delete(previousImageUrl);
        return UserProfileResponse.from(user);
    }

    @Transactional
    public UserProfileResponse deleteProfileImage(Long userId) {
        User user = getUser(userId);
        String previousImageUrl = user.getProfileImageUrl();
        user.updateProfileImage(null);
        profileImageStorage.delete(previousImageUrl);
        return UserProfileResponse.from(user);
    }

    private User getUser(Long id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
    }

    private int requiredLevel(int characterIndex) {
        return characterIndex == 0 ? 1 : characterIndex * 5;
    }
}
