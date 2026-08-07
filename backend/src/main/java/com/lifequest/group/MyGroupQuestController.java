package com.lifequest.group;

import com.lifequest.common.response.ApiResponse;
import com.lifequest.group.dto.GroupQuestResponse;
import com.lifequest.group.dto.PagedResponse;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/group-quests/me")
public class MyGroupQuestController {
    private final GroupQuestService service;

    public MyGroupQuestController(GroupQuestService service) {
        this.service = service;
    }

    @GetMapping
    public ApiResponse<PagedResponse<GroupQuestResponse>> list(
        @AuthenticationPrincipal Jwt jwt,
        @RequestParam GroupQuestScope scope,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") int size
    ) {
        return ApiResponse.success(
            service.listMine(Long.valueOf(jwt.getSubject()), scope, page, size));
    }
}
