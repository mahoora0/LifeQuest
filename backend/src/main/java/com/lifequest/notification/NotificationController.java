package com.lifequest.notification;

import com.lifequest.common.response.ApiResponse;
import com.lifequest.notification.dto.NotificationPageResponse;
import com.lifequest.notification.dto.ReadNotificationResponse;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {
    private final NotificationService notificationService;

    public NotificationController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @GetMapping
    public ApiResponse<NotificationPageResponse> notifications(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.success(notificationService.getNotifications(userId(jwt), page, size));
    }

    @PatchMapping("/{notificationId}/read")
    public ApiResponse<ReadNotificationResponse> markRead(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long notificationId) {
        return ApiResponse.success(notificationService.markRead(userId(jwt), notificationId));
    }

    @PatchMapping("/read")
    public ApiResponse<ReadNotificationResponse> markAllRead(
            @AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(notificationService.markAllRead(userId(jwt)));
    }

    private Long userId(Jwt jwt) {
        return Long.valueOf(jwt.getSubject());
    }
}
