package com.lifequest.growth;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.profile.ProfileItem;
import com.lifequest.profile.ProfileItemRepository;
import com.lifequest.profile.Title;
import com.lifequest.profile.TitleRepository;
import com.lifequest.profile.UserProfileItem;
import com.lifequest.profile.UserProfileItemRepository;
import com.lifequest.profile.UserTitle;
import com.lifequest.profile.UserTitleRepository;
import com.lifequest.user.User;
import java.util.ArrayList;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class RewardService {

    private final LevelRewardRepository levelRewardRepository;
    private final TitleRepository titleRepository;
    private final ProfileItemRepository profileItemRepository;
    private final UserTitleRepository userTitleRepository;
    private final UserProfileItemRepository userProfileItemRepository;

    public RewardService(
            LevelRewardRepository levelRewardRepository,
            TitleRepository titleRepository,
            ProfileItemRepository profileItemRepository,
            UserTitleRepository userTitleRepository,
            UserProfileItemRepository userProfileItemRepository) {
        this.levelRewardRepository = levelRewardRepository;
        this.titleRepository = titleRepository;
        this.profileItemRepository = profileItemRepository;
        this.userTitleRepository = userTitleRepository;
        this.userProfileItemRepository = userProfileItemRepository;
    }

    public List<String> grantLevelRewards(User user, int fromLevel, int toLevel) {
        List<String> granted = new ArrayList<>();
        for (LevelReward reward :
                levelRewardRepository.findAllByLevelBetweenOrderByLevelAscIdAsc(
                        fromLevel, toLevel)) {
            if (reward.getRewardType() == LevelReward.RewardType.TITLE) {
                grantTitle(user, reward, granted);
            } else {
                grantProfileItem(user, reward, granted);
            }
        }
        return List.copyOf(granted);
    }

    private void grantTitle(User user, LevelReward reward, List<String> granted) {
        if (userTitleRepository.existsByUserIdAndTitleId(
                user.getId(), reward.getRewardRefId())) {
            return;
        }
        Title title = titleRepository.findById(reward.getRewardRefId())
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
        userTitleRepository.save(new UserTitle(
                user, title, "LEVEL", (long) reward.getLevel()));
        if (user.getRepresentativeTitle() == null) {
            user.selectRepresentativeTitle(title);
        }
        granted.add(title.getName());
    }

    private void grantProfileItem(User user, LevelReward reward, List<String> granted) {
        if (userProfileItemRepository.existsByUserIdAndProfileItemId(
                user.getId(), reward.getRewardRefId())) {
            return;
        }
        ProfileItem item = profileItemRepository.findById(reward.getRewardRefId())
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
        userProfileItemRepository.save(new UserProfileItem(
                user, item, "LEVEL", (long) reward.getLevel()));
        if (item.getItemType() == ProfileItem.ItemType.BADGE
                && user.getRepresentativeBadge() == null) {
            user.selectRepresentativeBadge(item);
        }
        granted.add(item.getName());
    }
}
