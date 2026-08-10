package com.lifequest.admin;

import com.lifequest.admin.dto.AdminUserDetailResponse;
import com.lifequest.admin.dto.AdminUserPageResponse;
import com.lifequest.common.response.ApiResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/users")
public class AdminUserController {
    private final AdminUserService service;

    public AdminUserController(AdminUserService service) { this.service = service; }

    @GetMapping
    public ApiResponse<AdminUserPageResponse> users(
            @RequestParam(defaultValue = "") String query,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.success(service.getUsers(query, page, size));
    }

    @GetMapping("/{userId}")
    public ApiResponse<AdminUserDetailResponse> user(@PathVariable Long userId) {
        return ApiResponse.success(service.getUser(userId));
    }
}
