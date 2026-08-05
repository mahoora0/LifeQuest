package com.lifequest.notification.dto;

import com.lifequest.notification.Notification;
import com.lifequest.notification.NotificationKind;
import java.time.Duration;
import java.time.Instant;

public record NotificationResponse(
        Long id,
        NotificationKind kind,
        String title,
        String route,
        boolean read,
        String timeLabel,
        Instant createdAt) {
    public static NotificationResponse from(Notification notification) {
        return new NotificationResponse(
                notification.getId(), notification.getKind(), notification.getTitle(),
                notification.getRoute(), notification.isRead(),
                timeLabel(notification.getCreatedAt()), notification.getCreatedAt());
    }

    private static String timeLabel(Instant createdAt) {
        long minutes = Math.max(0, Duration.between(createdAt, Instant.now()).toMinutes());
        if (minutes < 1) return "방금";
        if (minutes < 60) return minutes + "분 전";
        long hours = minutes / 60;
        if (hours < 24) return hours + "시간 전";
        return hours / 24 + "일 전";
    }
}
