package com.lifequest.group;
import com.lifequest.common.response.ApiResponse;
import com.lifequest.group.dto.*;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/groups/{groupId}/quests")
public class GroupQuestController {
    private final GroupQuestService service;public GroupQuestController(GroupQuestService service){this.service=service;}
    @GetMapping public ApiResponse<PagedResponse<GroupQuestResponse>> list(@AuthenticationPrincipal Jwt jwt,@PathVariable Long groupId,@RequestParam GroupQuestScope scope,@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size){return ApiResponse.success(service.list(groupId,uid(jwt),scope,page,size));}
    @PostMapping public ApiResponse<GroupQuestResponse> create(@AuthenticationPrincipal Jwt jwt,@PathVariable Long groupId,@Valid @RequestBody CreateGroupQuestRequest r){return ApiResponse.success(service.create(groupId,uid(jwt),r));}
    @GetMapping("/{questId}") public ApiResponse<GroupQuestResponse> detail(@AuthenticationPrincipal Jwt jwt,@PathVariable Long groupId,@PathVariable Long questId){return ApiResponse.success(service.detail(groupId,uid(jwt),questId));}
    @PatchMapping("/{questId}") public ApiResponse<GroupQuestResponse> update(@AuthenticationPrincipal Jwt jwt,@PathVariable Long groupId,@PathVariable Long questId,@Valid @RequestBody UpdateGroupQuestRequest r){return ApiResponse.success(service.update(groupId,uid(jwt),questId,r));}
    @DeleteMapping("/{questId}") public ApiResponse<GroupQuestResponse> cancel(@AuthenticationPrincipal Jwt jwt,@PathVariable Long groupId,@PathVariable Long questId){return ApiResponse.success(service.cancel(groupId,uid(jwt),questId));}
    private Long uid(Jwt jwt){return Long.valueOf(jwt.getSubject());}
}
