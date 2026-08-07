package com.lifequest.admin;

import com.lifequest.admin.dto.DeleteLevelRewardResponse;
import com.lifequest.admin.dto.LevelRewardRequest;
import com.lifequest.admin.dto.LevelRewardResponse;
import com.lifequest.admin.dto.RewardCatalogResponse;
import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.growth.LevelReward;
import com.lifequest.growth.LevelRewardRepository;
import com.lifequest.profile.ProfileItem;
import com.lifequest.profile.ProfileItemRepository;
import com.lifequest.profile.Title;
import com.lifequest.profile.TitleRepository;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminLevelRewardService {
    private final LevelRewardRepository levelRewardRepository;
    private final TitleRepository titleRepository;
    private final ProfileItemRepository profileItemRepository;

    public AdminLevelRewardService(
            LevelRewardRepository levelRewardRepository,
            TitleRepository titleRepository,
            ProfileItemRepository profileItemRepository) {
        this.levelRewardRepository = levelRewardRepository;
        this.titleRepository = titleRepository;
        this.profileItemRepository = profileItemRepository;
    }

    @Transactional(readOnly = true)
    public List<LevelRewardResponse> getRewards() {
        return levelRewardRepository.findAllByOrderByLevelAscIdAsc().stream()
                .map(this::response)
                .toList();
    }

    @Transactional(readOnly = true)
    public RewardCatalogResponse getCatalog() {
        return new RewardCatalogResponse(
                titleRepository.findAllByAcquireTypeOrderById("LEVEL").stream()
                        .map(RewardCatalogResponse.TitleOption::from).toList(),
                profileItemRepository.findAll().stream()
                        .map(RewardCatalogResponse.ProfileItemOption::from).toList());
    }

    @Transactional
    public LevelRewardResponse create(LevelRewardRequest request) {
        validateReference(request.rewardType(), request.rewardRefId());
        if (levelRewardRepository.existsByLevelAndRewardTypeAndRewardRefId(
                request.level(), request.rewardType(), request.rewardRefId())) {
            throw new BusinessException(ErrorCode.CONFLICT);
        }
        LevelReward reward = levelRewardRepository.save(new LevelReward(
                request.level(), request.rewardType(), request.rewardRefId(),
                normalizeDescription(request.description())));
        return response(reward);
    }

    @Transactional
    public LevelRewardResponse update(Long rewardId, LevelRewardRequest request) {
        LevelReward reward = getReward(rewardId);
        validateReference(request.rewardType(), request.rewardRefId());
        if (levelRewardRepository.existsByLevelAndRewardTypeAndRewardRefIdAndIdNot(
                request.level(), request.rewardType(), request.rewardRefId(), rewardId)) {
            throw new BusinessException(ErrorCode.CONFLICT);
        }
        reward.update(
                request.level(), request.rewardType(), request.rewardRefId(),
                normalizeDescription(request.description()));
        return response(reward);
    }

    @Transactional
    public DeleteLevelRewardResponse delete(Long rewardId) {
        LevelReward reward = getReward(rewardId);
        levelRewardRepository.delete(reward);
        return new DeleteLevelRewardResponse(rewardId, true);
    }

    private LevelReward getReward(Long rewardId) {
        return levelRewardRepository.findById(rewardId)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
    }

    private void validateReference(LevelReward.RewardType type, Long referenceId) {
        boolean exists = switch (type) {
            case TITLE -> titleRepository.existsByIdAndAcquireType(referenceId, "LEVEL");
            case PROFILE_ITEM -> profileItemRepository.existsById(referenceId);
        };
        if (!exists) throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
    }

    private LevelRewardResponse response(LevelReward reward) {
        if (reward.getRewardType() == LevelReward.RewardType.TITLE) {
            Title title = titleRepository.findById(reward.getRewardRefId())
                    .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
            return LevelRewardResponse.of(reward, title.getCode(), title.getName());
        }
        ProfileItem item = profileItemRepository.findById(reward.getRewardRefId())
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
        return LevelRewardResponse.of(reward, item.getCode(), item.getName());
    }

    private String normalizeDescription(String description) {
        return description == null || description.isBlank() ? null : description.trim();
    }
}
