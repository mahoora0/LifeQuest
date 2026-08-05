package com.lifequest.admin;

import com.lifequest.admin.dto.DeleteLevelRewardResponse;
import com.lifequest.admin.dto.LevelRewardRequest;
import com.lifequest.admin.dto.LevelRewardResponse;
import com.lifequest.admin.dto.RewardCatalogResponse;
import com.lifequest.common.response.ApiResponse;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/level-rewards")
public class AdminLevelRewardController {
    private final AdminLevelRewardService service;

    public AdminLevelRewardController(AdminLevelRewardService service) {
        this.service = service;
    }

    @GetMapping
    public ApiResponse<List<LevelRewardResponse>> rewards() {
        return ApiResponse.success(service.getRewards());
    }

    @GetMapping("/catalog")
    public ApiResponse<RewardCatalogResponse> catalog() {
        return ApiResponse.success(service.getCatalog());
    }

    @PostMapping
    public ResponseEntity<ApiResponse<LevelRewardResponse>> create(
            @Valid @RequestBody LevelRewardRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(service.create(request)));
    }

    @PatchMapping("/{rewardId}")
    public ApiResponse<LevelRewardResponse> update(
            @PathVariable Long rewardId,
            @Valid @RequestBody LevelRewardRequest request) {
        return ApiResponse.success(service.update(rewardId, request));
    }

    @DeleteMapping("/{rewardId}")
    public ApiResponse<DeleteLevelRewardResponse> delete(@PathVariable Long rewardId) {
        return ApiResponse.success(service.delete(rewardId));
    }
}
