package com.lifequest.admin.dto;

import com.lifequest.user.User;
import com.lifequest.user.UserRole;
import java.time.Instant;
import java.util.List;

public record AdminUserPageResponse(
        List<UserRow> content,
        int page,
        int size,
        long totalElements,
        int totalPages,
        UserStats stats) {

    public record UserRow(Long id, String nickname, String email, String profileImageUrl,
                          int level, int totalExp, Instant createdAt, UserRole role) {
        public static UserRow from(User user) {
            return new UserRow(user.getId(), user.getNickname(), user.getEmail(),
                    user.getProfileImageUrl(), user.getLevel(), user.getTotalExp(),
                    user.getCreatedAt(), user.getRole());
        }
    }

    public record UserStats(long totalUsers, long todayJoined, double averageLevel) {}
}
