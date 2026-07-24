package com.lifequest.user.dto;

import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record UpdateProfileRequest(
        @Size(min = 2, max = 20, message = "닉네임은 2~20자로 입력해 주세요.")
        @Pattern(
                regexp = "^[가-힣a-zA-Z0-9_]+$",
                message = "닉네임은 한글, 영문, 숫자, 밑줄만 사용할 수 있습니다.")
        String nickname,

        @Size(max = 500, message = "프로필 이미지 주소가 너무 깁니다.")
        String profileImageUrl) {
}
