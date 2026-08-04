package com.lifequest.group;
import com.lifequest.common.response.ApiResponse;
import com.lifequest.group.dto.*;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/groups")
public class GroupController {
    private final GroupService service;
    public GroupController(GroupService service){this.service=service;}
    @PostMapping public ApiResponse<GroupResponse> create(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody CreateGroupRequest r){return ApiResponse.success(service.create(uid(jwt),r));}
    @GetMapping("/me") public ApiResponse<List<GroupSummaryResponse>> mine(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(service.mine(uid(jwt)));}
    @GetMapping("/search") public ApiResponse<PagedResponse<GroupSummaryResponse>> search(@AuthenticationPrincipal Jwt jwt,@RequestParam String query,@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size){return ApiResponse.success(service.search(uid(jwt),query,page,size));}
    @GetMapping("/{groupId}") public ApiResponse<GroupResponse> detail(@AuthenticationPrincipal Jwt jwt,@PathVariable Long groupId){return ApiResponse.success(service.detail(groupId,uid(jwt)));}
    @PatchMapping("/{groupId}") public ApiResponse<GroupResponse> update(@AuthenticationPrincipal Jwt jwt,@PathVariable Long groupId,@Valid @RequestBody UpdateGroupRequest r){return ApiResponse.success(service.update(groupId,uid(jwt),r));}
    @DeleteMapping("/{groupId}") public ApiResponse<Boolean> archive(@AuthenticationPrincipal Jwt jwt,@PathVariable Long groupId){service.archive(groupId,uid(jwt));return ApiResponse.success(true);}
    @PostMapping("/{groupId}/owner-transfer") public ApiResponse<GroupResponse> transfer(@AuthenticationPrincipal Jwt jwt,@PathVariable Long groupId,@Valid @RequestBody TransferGroupOwnerRequest r){return ApiResponse.success(service.transferOwner(groupId,uid(jwt),r.newOwnerUserId()));}
    private Long uid(Jwt jwt){return Long.valueOf(jwt.getSubject());}
}
