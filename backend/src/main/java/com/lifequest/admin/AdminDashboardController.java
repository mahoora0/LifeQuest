package com.lifequest.admin;

import com.lifequest.admin.dto.AdminDashboardResponse;
import com.lifequest.common.response.ApiResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/dashboard")
public class AdminDashboardController {
    private final AdminDashboardService service;

    public AdminDashboardController(AdminDashboardService service) { this.service = service; }

    @GetMapping
    public ApiResponse<AdminDashboardResponse> dashboard() {
        return ApiResponse.success(service.getDashboard());
    }
}
