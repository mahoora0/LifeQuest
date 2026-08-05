package com.lifequest.notification;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.notification.dto.NotificationPageResponse;
import com.lifequest.notification.dto.ReadNotificationResponse;
import com.lifequest.user.User;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class NotificationService {
    private static final Sort NEWEST_FIRST = Sort.by(
            Sort.Order.desc("createdAt"), Sort.Order.desc("id"));

    private final NotificationRepository notificationRepository;

    public NotificationService(NotificationRepository notificationRepository) {
        this.notificationRepository = notificationRepository;
    }

    @Transactional
    public void create(User recipient, NotificationKind kind, String title, String route) {
        notificationRepository.save(new Notification(recipient, kind, title, route));
    }

    @Transactional(readOnly = true)
    public NotificationPageResponse getNotifications(Long userId, int page, int size) {
        validatePage(page, size);
        var notifications = notificationRepository.findAllByUserId(
                userId, PageRequest.of(page, size, NEWEST_FIRST));
        return NotificationPageResponse.from(
                notifications, notificationRepository.countByUserIdAndReadAtIsNull(userId));
    }

    @Transactional
    public ReadNotificationResponse markRead(Long userId, Long notificationId) {
        Notification notification = notificationRepository.findByIdAndUserId(notificationId, userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));
        if (notification.isRead()) return new ReadNotificationResponse(0);
        notification.markRead();
        return new ReadNotificationResponse(1);
    }

    @Transactional
    public ReadNotificationResponse markAllRead(Long userId) {
        List<Notification> unread = notificationRepository.findAllByUserIdAndReadAtIsNull(userId);
        unread.forEach(Notification::markRead);
        return new ReadNotificationResponse(unread.size());
    }

    private void validatePage(int page, int size) {
        if (page < 0 || size < 1 || size > 100) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
    }
}
