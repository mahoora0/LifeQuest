package com.lifequest.admin;

import com.lifequest.admin.dto.AdminQuestPageResponse;
import com.lifequest.admin.dto.AdminQuestRequest;
import com.lifequest.admin.dto.AdminQuestResponse;
import com.lifequest.admin.dto.DeactivateQuestResponse;
import com.lifequest.admin.dto.UpdateAdminQuestRequest;
import com.lifequest.common.response.ApiResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/quests")
public class AdminQuestController {
    private final AdminQuestService adminQuestService;

    public AdminQuestController(AdminQuestService adminQuestService) {
        this.adminQuestService = adminQuestService;
    }

    @GetMapping
    public ApiResponse<AdminQuestPageResponse> quests(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.success(adminQuestService.getQuests(page, size));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<AdminQuestResponse>> create(
            @Valid @RequestBody AdminQuestRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(adminQuestService.create(request)));
    }

    @PatchMapping("/{questId}")
    public ApiResponse<AdminQuestResponse> update(
            @PathVariable Long questId,
            @Valid @RequestBody UpdateAdminQuestRequest request) {
        return ApiResponse.success(adminQuestService.update(questId, request));
    }

    @DeleteMapping("/{questId}")
    public ApiResponse<DeactivateQuestResponse> deactivate(@PathVariable Long questId) {
        return ApiResponse.success(adminQuestService.deactivate(questId));
    }
}
