package com.lifequest.notification.dto;

import com.lifequest.notification.Notification;
import java.util.List;
import org.springframework.data.domain.Page;

public record NotificationPageResponse(
        List<NotificationResponse> content,
        long unreadCount,
        int page,
        int size,
        long totalElements,
        int totalPages) {
    public static NotificationPageResponse from(Page<Notification> result, long unreadCount) {
        return new NotificationPageResponse(
                result.getContent().stream().map(NotificationResponse::from).toList(),
                unreadCount, result.getNumber(), result.getSize(),
                result.getTotalElements(), result.getTotalPages());
    }
}
