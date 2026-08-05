package com.lifequest.social;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.quest.repository.QuestCompletionRepository;
import com.lifequest.notification.NotificationKind;
import com.lifequest.notification.NotificationService;
import com.lifequest.social.dto.DeleteFriendResponse;
import com.lifequest.social.dto.FriendActivitySummary;
import com.lifequest.social.dto.FriendPageResponse;
import com.lifequest.social.dto.FriendProfileResponse;
import com.lifequest.social.dto.FriendRequestAction;
import com.lifequest.social.dto.FriendRequestPageResponse;
import com.lifequest.social.dto.RespondFriendRequestResponse;
import com.lifequest.social.dto.SendFriendRequestResponse;
import com.lifequest.social.dto.SentFriendRequestPageResponse;
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class FriendService {

    private final UserRepository userRepository;
    private final FriendRequestRepository friendRequestRepository;
    private final FriendshipRepository friendshipRepository;
    private final QuestCompletionRepository questCompletionRepository;
    private final NotificationService notificationService;

    public FriendService(
            UserRepository userRepository,
            FriendRequestRepository friendRequestRepository,
            FriendshipRepository friendshipRepository,
            QuestCompletionRepository questCompletionRepository,
            NotificationService notificationService) {
        this.userRepository = userRepository;
        this.friendRequestRepository = friendRequestRepository;
        this.friendshipRepository = friendshipRepository;
        this.questCompletionRepository = questCompletionRepository;
        this.notificationService = notificationService;
    }

    // 친구 요청 전송
    @Transactional
    public SendFriendRequestResponse sendRequest(Long currentUserId, Long receiverId) {
        if (currentUserId.equals(receiverId)) {
            throw new BusinessException(ErrorCode.SELF_FRIEND_REQUEST_NOT_ALLOWED);
        }

        User sender = getUser(currentUserId);
        User receiver = getUser(receiverId);

        if (friendshipRepository.existsByUserIdAndFriendId(currentUserId, receiverId)
                || hasPendingRequest(currentUserId, receiverId)
                || hasPendingRequest(receiverId, currentUserId)) {
            throw new BusinessException(ErrorCode.DUPLICATE_FRIEND_REQUEST);
        }

        FriendRequest saved = friendRequestRepository.save(new FriendRequest(sender, receiver));
        notificationService.create(
                receiver,
                NotificationKind.FRIEND_REQUEST,
                sender.getNickname() + "님이 친구 요청을 보냈어요",
                "/friends/requests");
        return SendFriendRequestResponse.from(saved);
    }

    // 받은 친구 요청 목록 조회
    @Transactional(readOnly = true)
    public FriendRequestPageResponse getReceivedRequests(
            Long currentUserId,
            int page,
            int size) {
        validatePage(page, size);

        Page<FriendRequest> requests = friendRequestRepository
                .findAllByReceiverIdAndStatusOrderByCreatedAtDescIdDesc(
                        currentUserId,
                        FriendRequestStatus.PENDING,
                        PageRequest.of(page, size));
        return FriendRequestPageResponse.from(requests);
    }

    @Transactional(readOnly = true)
    public SentFriendRequestPageResponse getSentRequests(
            Long currentUserId,
            int page,
            int size) {
        validatePage(page, size);
        return SentFriendRequestPageResponse.from(friendRequestRepository
                .findAllBySenderIdAndStatusOrderByCreatedAtDescIdDesc(
                        currentUserId,
                        FriendRequestStatus.PENDING,
                        PageRequest.of(page, size)));
    }

    // 친구 목록 조회
    @Transactional(readOnly = true)
    public FriendPageResponse getFriends(Long currentUserId, int page, int size) {
        validatePage(page, size);

        Page<Friendship> friendships = friendshipRepository
                .findAllByUserIdOrderByCreatedAtDescIdDesc(
                        currentUserId,
                        PageRequest.of(page, size));
        return FriendPageResponse.from(friendships);
    }

    // 친구 관계 삭제
    @Transactional
    public DeleteFriendResponse deleteFriend(Long currentUserId, Long friendId) {
        if (!friendshipRepository.existsByUserIdAndFriendId(currentUserId, friendId)) {
            throw new BusinessException(ErrorCode.FRIENDSHIP_NOT_FOUND);
        }

        friendshipRepository.deleteByUserIdAndFriendId(currentUserId, friendId);
        friendshipRepository.deleteByUserIdAndFriendId(friendId, currentUserId);
        return DeleteFriendResponse.success();
    }

    // 친구 공개 프로필과 활동 요약 조회
    @Transactional(readOnly = true)
    public FriendProfileResponse getFriendProfile(Long currentUserId, Long friendId) {
        if (!friendshipRepository.existsByUserIdAndFriendId(currentUserId, friendId)) {
            throw new BusinessException(ErrorCode.FRIENDSHIP_NOT_FOUND);
        }

        User currentUser = getUser(currentUserId);
        User friend = getUser(friendId);
        return FriendProfileResponse.of(
                friend,
                activitySummary(currentUser),
                activitySummary(friend));
    }

    // 친구 요청 수락 또는 거절
    @Transactional
    public RespondFriendRequestResponse respondToRequest(
            Long currentUserId,
            Long requestId,
            FriendRequestAction action) {
        FriendRequest request = friendRequestRepository.findByIdForUpdate(requestId)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));

        if (!request.getReceiver().getId().equals(currentUserId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
        if (request.getStatus() != FriendRequestStatus.PENDING) {
            throw new BusinessException(ErrorCode.CONFLICT);
        }
        if (action == null) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }

        switch (action) {
            case ACCEPT -> {
                accept(request);
                notificationService.create(
                        request.getSender(),
                        NotificationKind.FRIEND_ACCEPTED,
                        request.getReceiver().getNickname() + "님이 친구 요청을 수락했어요",
                        "/friends");
            }
            case REJECT -> request.reject();
        }

        return RespondFriendRequestResponse.from(request);
    }

    // 친구 요청 수락 처리
    private void accept(FriendRequest request) {
        Long senderId = request.getSender().getId();
        Long receiverId = request.getReceiver().getId();
        if (friendshipRepository.existsByUserIdAndFriendId(senderId, receiverId)
                || friendshipRepository.existsByUserIdAndFriendId(receiverId, senderId)) {
            throw new BusinessException(ErrorCode.CONFLICT);
        }

        friendshipRepository.saveAll(List.of(
                new Friendship(request.getSender(), request.getReceiver()),
                new Friendship(request.getReceiver(), request.getSender())));
        request.accept();
    }

    // 현재 사용자와 다른 사용자 간에 대기 중인 친구 요청이 있는지 확인
    private boolean hasPendingRequest(Long senderId, Long receiverId) {
        return friendRequestRepository.existsBySenderIdAndReceiverIdAndStatus(
                senderId,
                receiverId,
                FriendRequestStatus.PENDING);
    }

    // 사용자 ID로 User 엔티티를 조회, 존재하지 않으면 예외 발생
    private User getUser(Long userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
    }

    private FriendActivitySummary activitySummary(User user) {
        return FriendActivitySummary.of(
                user,
                questCompletionRepository.countByUserId(user.getId()),
                questCompletionRepository.countDistinctVisitedPlacesByUserId(user.getId()));
    }

    // 페이지 번호와 페이지 크기를 검증, 유효하지 않으면 예외 발생
    private void validatePage(int page, int size) {
        if (page < 0 || size < 1 || size > 100) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
    }
}
