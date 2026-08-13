package com.lifequest.user;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.user.dto.UpdateProfileRequest;
import com.lifequest.user.dto.CharacterResponse;
import com.lifequest.user.dto.AccessoryCollectionResponse;
import com.lifequest.user.dto.AccessoryResponse;
import com.lifequest.user.dto.ProfileItemResponse;
import com.lifequest.user.dto.RewardHistoryResponse;
import com.lifequest.user.dto.TitleCollectionResponse;
import com.lifequest.user.dto.TitleResponse;
import com.lifequest.user.dto.UserProfileResponse;
import com.lifequest.growth.GrowthService;
import com.lifequest.growth.ExpLog;
import com.lifequest.growth.ExpLogRepository;
import com.lifequest.growth.LevelReward;
import com.lifequest.growth.LevelRewardRepository;
import com.lifequest.quest.domain.QuestFeature;
import com.lifequest.quest.repository.QuestRepository;
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
import com.lifequest.profile.TitleRepository;
import java.time.Clock;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.IntStream;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import com.lifequest.user.dto.UserSearchPageResponse;
import com.lifequest.user.dto.UserSearchResponse;
import com.lifequest.user.dto.FriendCodeResponse;
import org.springframework.data.domain.PageImpl;
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
    private final ProfileImageStorage profileImageStorage;
    private final QuestUnlockPolicy questUnlockPolicy;
    private final ExpLogRepository expLogRepository;
    private final LevelRewardRepository levelRewardRepository;
    private final QuestRepository questRepository;
    private final TitleRepository titleRepository;
    private final Clock clock;

    public UserService(
            UserRepository userRepository,
            AvatarCharacterRepository characterRepository,
            UserTitleRepository userTitleRepository,
            UserProfileItemRepository userProfileItemRepository,
            UserCharacterAccessoryRepository userCharacterAccessoryRepository,
            ProfileItemRepository profileItemRepository,
            ProfileImageStorage profileImageStorage,
            QuestUnlockPolicy questUnlockPolicy,
            ExpLogRepository expLogRepository,
            LevelRewardRepository levelRewardRepository,
            QuestRepository questRepository,
            TitleRepository titleRepository,
            Clock clock) {
        this.userRepository = userRepository;
        this.characterRepository = characterRepository;
        this.userTitleRepository = userTitleRepository;
        this.userProfileItemRepository = userProfileItemRepository;
        this.userCharacterAccessoryRepository = userCharacterAccessoryRepository;
        this.profileItemRepository = profileItemRepository;
        this.profileImageStorage = profileImageStorage;
        this.questUnlockPolicy = questUnlockPolicy;
        this.expLogRepository = expLogRepository;
        this.levelRewardRepository = levelRewardRepository;
        this.questRepository = questRepository;
        this.titleRepository = titleRepository;
        this.clock = clock;
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
        List<AccessoryResponse> accessories = accessoryResponses(user.getLevel());
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

    private List<AccessoryResponse> accessoryResponses(int userLevel) {
        List<ProfileItem> accessories = profileItemRepository
                .findAllByItemTypeOrderById(ProfileItem.ItemType.OUTFIT);
        return IntStream.range(0, accessories.size())
                .mapToObj(index -> {
                    int requiredLevel = requiredAccessoryLevel(index);
                    return AccessoryResponse.from(
                            accessories.get(index),
                            requiredLevel,
                            userLevel >= requiredLevel);
                })
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
        List<ProfileItem> accessories = profileItemRepository
                .findAllByItemTypeOrderById(ProfileItem.ItemType.OUTFIT);
        int accessoryIndex = accessories.indexOf(accessory);
        if (accessoryIndex < 0
                || user.getLevel() < requiredAccessoryLevel(accessoryIndex)) {
            throw new BusinessException(ErrorCode.ACCESSORY_LOCKED);
        }
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
    public RewardHistoryResponse getRewards(Long userId, int page, int size) {
        if (page < 0 || size < 1 || size > 100) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        User user = getUser(userId);
        List<UserTitle> ownedTitles =
                userTitleRepository.findAllByUserIdOrderByAcquiredAtDesc(userId);
        List<UserProfileItem> ownedItems =
                userProfileItemRepository.findAllByUserIdOrderByAcquiredAtDesc(userId);

        int levelStartExp = GrowthService.cumulativeExpForLevel(user.getLevel());
        int currentLevelExp = user.getTotalExp() - levelStartExp;
        int nextLevelExp = GrowthService.requiredExpForNextLevel(user.getLevel());
        int remainingExp = Math.max(0, nextLevelExp - currentLevelExp);
        Double averageReward = questRepository.averageExpRewardForPublicActiveQuests();
        Integer questsToNextLevel = averageReward == null || averageReward <= 0
                ? null
                : (int) Math.ceil(remainingExp / averageReward);

        List<RewardHistoryResponse.ReceivedReward> received = receivedRewards(
                ownedTitles, ownedItems, page, size);
        return new RewardHistoryResponse(
                user.getLevel(),
                currentLevelExp,
                nextLevelExp,
                questsToNextLevel,
                nextMilestone(user.getLevel()),
                received,
                weeklyExp(userId),
                ownedTitles.stream()
                        .map(TitleResponse::from)
                        .toList(),
                ownedItems.stream()
                        .map(ProfileItemResponse::from)
                        .toList());
    }

    private RewardHistoryResponse.NextMilestone nextMilestone(int currentLevel) {
        List<LevelReward> future = levelRewardRepository.findAllByOrderByLevelAscIdAsc().stream()
                .filter(reward -> reward.getLevel() > currentLevel)
                .toList();
        if (future.isEmpty()) {
            return null;
        }
        int level = future.get(0).getLevel();
        String rewards = future.stream()
                .filter(reward -> reward.getLevel() == level)
                .map(this::rewardName)
                .collect(Collectors.joining(" · "));
        return new RewardHistoryResponse.NextMilestone(
                level, "Lv." + level + " · " + rewards);
    }

    private String rewardName(LevelReward reward) {
        if (reward.getRewardType() == LevelReward.RewardType.TITLE) {
            return titleRepository.findById(reward.getRewardRefId())
                    .map(title -> "칭호 \"" + title.getName() + "\"")
                    .orElse("칭호");
        }
        return profileItemRepository.findById(reward.getRewardRefId())
                .map(item -> "아이템 \"" + item.getName() + "\"")
                .orElse("아이템");
    }

    private List<RewardHistoryResponse.ReceivedReward> receivedRewards(
            List<UserTitle> titles,
            List<UserProfileItem> items,
            int page,
            int size) {
        List<RewardHistoryResponse.ReceivedReward> rewards = new ArrayList<>();
        titles.stream()
                .filter(title -> "LEVEL".equals(title.getSourceType()))
                .map(title -> new RewardHistoryResponse.ReceivedReward(
                        title.getSourceId().intValue(),
                        title.getTitle().getName(),
                        "TITLE",
                        title.getAcquiredAt(),
                        relativeTime(title.getAcquiredAt()),
                        "Lv." + title.getSourceId() + " 달성"))
                .forEach(rewards::add);
        items.stream()
                .filter(item -> "LEVEL".equals(item.getSourceType()))
                .map(item -> new RewardHistoryResponse.ReceivedReward(
                        item.getSourceId().intValue(),
                        item.getProfileItem().getName(),
                        "PROFILE_ITEM",
                        item.getAcquiredAt(),
                        relativeTime(item.getAcquiredAt()),
                        "Lv." + item.getSourceId() + " 달성"))
                .forEach(rewards::add);
        rewards.sort(Comparator.comparing(
                RewardHistoryResponse.ReceivedReward::acquiredAt).reversed());
        int from = Math.min(page * size, rewards.size());
        int to = Math.min(from + size, rewards.size());
        return List.copyOf(rewards.subList(from, to));
    }

    private String relativeTime(Instant acquiredAt) {
        LocalDate acquiredDate = acquiredAt.atZone(clock.getZone()).toLocalDate();
        LocalDate today = LocalDate.now(clock);
        long days = ChronoUnit.DAYS.between(acquiredDate, today);
        if (days <= 0) return "오늘";
        if (days == 1) return "어제";
        if (days < 7) return days + "일 전";
        return acquiredDate.toString().replace('-', '.');
    }

    private List<RewardHistoryResponse.DailyExp> weeklyExp(Long userId) {
        LocalDate today = LocalDate.now(clock);
        LocalDate monday = today.with(DayOfWeek.MONDAY);
        Instant from = monday.atStartOfDay(clock.getZone()).toInstant();
        Instant to = monday.plusDays(7).atStartOfDay(clock.getZone()).toInstant();
        int[] totals = new int[7];
        for (ExpLog log : expLogRepository
                .findAllByUserIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThanOrderByCreatedAtAsc(
                        userId, from, to)) {
            int index = log.getCreatedAt().atZone(clock.getZone()).getDayOfWeek().getValue() - 1;
            totals[index] += log.getExpAmount();
        }
        String[] labels = {"월", "화", "수", "목", "금", "토", "일"};
        return IntStream.range(0, labels.length)
                .mapToObj(index -> new RewardHistoryResponse.DailyExp(labels[index], totals[index]))
                .toList();
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

        Page<UserSearchResponse> result;
        if (keyword.regionMatches(true, 0, "LQ-", 0, 3)) {
            List<UserSearchResponse> matches = userRepository
                    .findByFriendCodeIgnoreCaseAndIdNot(keyword, currentUserId)
                    .map(UserSearchResponse::from)
                    .map(List::of)
                    .orElseGet(List::of);
            result = new PageImpl<>(matches, pageable, matches.size());
        } else {
            result = userRepository
                    .findByNicknameContainingIgnoreCaseAndIdNot(
                            keyword,
                            currentUserId,
                            pageable)
                    .map(UserSearchResponse::from);
        }

        return UserSearchPageResponse.from(result);
    }

    private int requiredLevel(int characterIndex) {
        return characterIndex == 0 ? 1 : characterIndex * 5;
    }

    private int requiredAccessoryLevel(int accessoryIndex) {
        return (accessoryIndex + 1) * 2;
    }

    @Transactional
    public FriendCodeResponse getFriendCode(Long userId) {
        User user = getUser(userId);
        if (user.getFriendCode() == null) {
            user.assignFriendCode(friendCodeFor(user.getId()));
        }
        return new FriendCodeResponse(user.getFriendCode());
    }

    private String friendCodeFor(Long userId) {
        return "LQ-" + String.format("%08X", userId);
    }
}
