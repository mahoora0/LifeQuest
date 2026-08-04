package com.lifequest.social;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.social.dto.RankingPageResponse;
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class RankingService {

    private static final Sort RANKING_ORDER = Sort.by(
            Sort.Order.desc("totalExp"),
            Sort.Order.asc("id"));

    private final UserRepository userRepository;

    public RankingService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Transactional(readOnly = true)
    public RankingPageResponse getGlobalRanking(Long currentUserId, int page, int size) {
        PageRequest pageable = pageable(page, size);
        Page<User> users = userRepository.findAll(pageable);
        return RankingPageResponse.from(users, currentUserId);
    }

    @Transactional(readOnly = true)
    public RankingPageResponse getFriendRanking(Long currentUserId, int page, int size) {
        PageRequest pageable = pageable(page, size);
        Page<User> users = userRepository.findCurrentUserAndFriends(currentUserId, pageable);
        return RankingPageResponse.from(users, currentUserId);
    }

    private PageRequest pageable(int page, int size) {
        if (page < 0 || size < 1 || size > 100) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        return PageRequest.of(page, size, RANKING_ORDER);
    }
}
