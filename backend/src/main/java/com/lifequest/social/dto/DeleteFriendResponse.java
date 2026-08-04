package com.lifequest.social.dto;

// 친구 관계 삭제 결과를 나타내는 DTO
public record DeleteFriendResponse(boolean deleted) {

    public static DeleteFriendResponse success() {
        return new DeleteFriendResponse(true);
    }
}
