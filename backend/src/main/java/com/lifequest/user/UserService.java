package com.lifequest.user;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.user.dto.UpdateProfileRequest;
import com.lifequest.user.dto.BadgeCollectionResponse;
import com.lifequest.user.dto.CharacterResponse;
import com.lifequest.user.dto.AccessoryCollectionResponse;
import com.lifequest.user.dto.AccessoryResponse;
import com.lifequest.user.dto.ProfileItemResponse;
import com.lifequest.user.dto.RewardHistoryResponse;
import com.lifequest.user.dto.TitleCollectionResponse;
import com.lifequest.user.dto.TitleResponse;
import com.lifequest.user.dto.UserProfileResponse;
import com.lifequest.growth.GrowthService;
import com.lifequest.growth.LevelReward;
import com.lifequest.growth.LevelRewardRepository;
import com.lifequest.quest.domain.QuestFeature;
import com.lifequest.quest.service.QuestUnlockPolicy;
import com.lifequest.profile.AvatarCharacter;
import com.lifequest.profile.AvatarCharacterRepository;
import com.lifequest.profile.ProfileItem;
import com.lifequest.profile.ProfileItemRepository;
import com.lifequest.profile.ProfileImageStorage;
import com.lifequest.profile.UserProfileItem;
import com.lifequest.profile.UserProfileItemRepository;
import com.lifequest.profile.UserCharacterAccessory;
import com.lifequest.profile.UserCharacterAccessoryRepository;
import com.lifequest.profile.UserTitle;
import com.lifequest.profile.UserTitleRepository;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import com.lifequest.user.dto.UserSearchPageResponse;
import com.lifequest.user.dto.UserSearchResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final AvatarCharacterRepository characterRepository;
    private final UserTitleRepository userTitleRepository;
    private final UserProfileItemRepository userProfileItemRepository;
    private final UserCharacterAccessoryRepository userCharacterAccessoryRepository;
    private final ProfileItemRepository profileItemRepository;
    private final LevelRewardRepository levelRewardRepository;
    private final ProfileImageStorage profileImageStorage;
    private final QuestUnlockPolicy questUnlockPolicy;

    public UserService(
            UserRepository userRepository,
            AvatarCharacterRepository characterRepository,
            UserTitleRepository userTitleRepository,
            UserProfileItemRepository userProfileItemRepository,
            UserCharacterAccessoryRepository userCharacterAccessoryRepository,
            ProfileItemRepository profileItemRepository,
            LevelRewardRepository levelRewardRepository,
            ProfileImageStorage profileImageStorage,
            QuestUnlockPolicy questUnlockPolicy) {
        this.userRepository = userRepository;
        this.characterRepository = characterRepository;
        this.userTitleRepository = userTitleRepository;
        this.userProfileItemRepository = userProfileItemRepository;
        this.userCharacterAccessoryRepository = userCharacterAccessoryRepository;
        this.profileItemRepository = profileItemRepository;
        this.levelRewardRepository = levelRewardRepository;
        this.profileImageStorage = profileImageStorage;
        this.questUnlockPolicy = questUnlockPolicy;
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
    public Map<String, Object> getLevel(Long userId) {
        User user = getUser(userId);
        int levelStartExp = GrowthService.cumulativeExpForLevel(user.getLevel());
        int requiredExp = GrowthService.requiredExpForNextLevel(user.getLevel());
        return Map.of(
                "level", user.getLevel(),
                "totalExp", user.getTotalExp(),
                "currentLevelExp", user.getTotalExp() - levelStartExp,
                "nextLevelRequiredExp", requiredExp,
                "unlocks", Map.of(
                        "daily", unlock(user.getLevel(), QuestFeature.DAILY),
                        "weekly", unlock(user.getLevel(), QuestFeature.WEEKLY),
                        "coop", unlock(user.getLevel(), QuestFeature.COOP)));
    }

    private Map<String, Object> unlock(int level, QuestFeature feature) {
        return Map.of(
                "unlocked", questUnlockPolicy.isUnlocked(level, feature),
                "requiredLevel", questUnlockPolicy.requiredLevel(feature));
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
        user.selectAccessory(userCharacterAccessoryRepository
                .findByUserIdAndCharacterId(userId, characterId)
                .map(UserCharacterAccessory::getAccessory)
                .orElse(null));
        return UserProfileResponse.from(user);
    }

    @Transactional(readOnly = true)
    public AccessoryCollectionResponse getAccessories(Long userId) {
        User user = getUser(userId);
        List<AccessoryResponse> accessories = accessoryResponses();
        return new AccessoryCollectionResponse(
                accessories,
                user.getSelectedAccessory() == null
                        ? null
                        : user.getSelectedAccessory().getId(),
                userCharacterAccessoryRepository.findAllByUserId(userId).stream()
                        .collect(Collectors.toMap(
                                equipped -> equipped.getCharacter().getId(),
                                equipped -> equipped.getAccessory().getId())));
    }

    private List<AccessoryResponse> accessoryResponses() {
        List<ProfileItem> accessories = profileItemRepository
                .findAllByItemTypeOrderById(ProfileItem.ItemType.OUTFIT);
        Map<Long, Integer> requiredLevels = levelRewardRepository
                .findAllByRewardTypeOrderByLevelAscIdAsc(
                        LevelReward.RewardType.PROFILE_ITEM).stream()
                .filter(reward -> accessories.stream().anyMatch(
                        item -> item.getId().equals(reward.getRewardRefId())))
                .collect(Collectors.toMap(
                        LevelReward::getRewardRefId,
                        LevelReward::getLevel,
                        Math::min));
        return accessories.stream()
                .map(item -> AccessoryResponse.from(
                        item,
                        requiredLevels.get(item.getId()),
                        true))
                .toList();
    }

    @Transactional
    public UserProfileResponse selectAccessory(Long userId, Long accessoryId) {
        User user = getUser(userId);
        AvatarCharacter character = user.getSelectedCharacter();
        if (character == null) {
            throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        }
        var equipped = userCharacterAccessoryRepository
                .findByUserIdAndCharacterId(userId, character.getId());
        if (accessoryId == null) {
            equipped.ifPresent(userCharacterAccessoryRepository::delete);
            user.selectAccessory(null);
            return UserProfileResponse.from(user);
        }

        ProfileItem accessory = profileItemRepository.findById(accessoryId)
                .filter(item -> item.getItemType()
                        == ProfileItem.ItemType.OUTFIT)
                .orElseThrow(() -> new BusinessException(ErrorCode.FORBIDDEN));
        if (equipped.isPresent()) {
            equipped.get().changeAccessory(accessory);
        } else {
            userCharacterAccessoryRepository.save(
                    new UserCharacterAccessory(user, character, accessory));
        }
        user.selectAccessory(accessory);
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
                .filter(owned -> owned.getProfileItem().getItemType() == ProfileItem.ItemType.BADGE)
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
            UserProfileItem owned = userProfileItemRepository.findByUserIdAndProfileItemId(userId, badgeId)
                    .filter(item -> item.getProfileItem().getItemType() == ProfileItem.ItemType.BADGE)
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

    // 사용자 검색 조건 검증, 페이지·정렬 설정 및 Repository 호출
    @Transactional(readOnly = true)
    public UserSearchPageResponse searchUsers(
            Long currentUserId,
            String nickname,
            int page,
            int size) {
        String keyword = nickname == null ? "" : nickname.trim();

        if (keyword.isEmpty()) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }

        if (page < 0 || size < 1 || size > 100) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }

        PageRequest pageable = PageRequest.of(
                page,
                size,
                Sort.by(Sort.Direction.ASC, "nickname")
                        .and(Sort.by(Sort.Direction.ASC, "id")));

        Page<UserSearchResponse> result = userRepository
                .findByNicknameContainingIgnoreCaseAndIdNot(
                        keyword,
                        currentUserId,
                        pageable)
                .map(UserSearchResponse::from);

        return UserSearchPageResponse.from(result);
    }

    private int requiredLevel(int characterIndex) {
        return characterIndex == 0 ? 1 : characterIndex * 5;
    }
}
