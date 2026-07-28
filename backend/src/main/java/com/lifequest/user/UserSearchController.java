package com.lifequest.user;

import com.lifequest.common.response.ApiResponse;
import com.lifequest.user.dto.UserSearchPageResponse;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/users")
public class UserSearchController {

    private final UserService userService;

    public UserSearchController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping("/search")
    public ApiResponse<UserSearchPageResponse> search(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam("nickname") String nickname,
            @RequestParam(name = "page", defaultValue = "0") int page,
            @RequestParam(name = "size", defaultValue = "20") int size
    ) {
        Long currentUserId = Long.valueOf(jwt.getSubject());

        return ApiResponse.success(
                userService.searchUsers(
                        currentUserId,
                        nickname,
                        page,
                        size
                )
        );
    }
}
