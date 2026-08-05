package com.lifequest.group;
import com.lifequest.common.response.ApiResponse;
import com.lifequest.group.dto.*;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/groups")
public class GroupMembershipController {
    private final GroupMembershipService service;
    public GroupMembershipController(GroupMembershipService service){this.service=service;}
    @PostMapping("/{groupId}/invitations") public ApiResponse<GroupMemberResponse> invite(@AuthenticationPrincipal Jwt jwt,@PathVariable Long groupId,@Valid @RequestBody InviteGroupMemberRequest r){return ApiResponse.success(service.invite(groupId,uid(jwt),r.userId()));}
    @GetMapping("/invitations") public ApiResponse<PagedResponse<GroupMemberResponse>> invitations(@AuthenticationPrincipal Jwt jwt,@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size){return ApiResponse.success(service.invitations(uid(jwt),page,size));}
    @PostMapping("/invitations/{memberId}/accept") public ApiResponse<GroupMemberResponse> accept(@AuthenticationPrincipal Jwt jwt,@PathVariable Long memberId){return ApiResponse.success(service.acceptInvitation(memberId,uid(jwt)));}
    @PostMapping("/invitations/{memberId}/decline") public ApiResponse<GroupMemberResponse> decline(@AuthenticationPrincipal Jwt jwt,@PathVariable Long memberId){return ApiResponse.success(service.declineInvitation(memberId,uid(jwt)));}
    @PostMapping("/{groupId}/join-requests") public ApiResponse<GroupMemberResponse> requestJoin(@AuthenticationPrincipal Jwt jwt,@PathVariable Long groupId){return ApiResponse.success(service.requestJoin(groupId,uid(jwt)));}
    @GetMapping("/{groupId}/join-requests") public ApiResponse<PagedResponse<GroupMemberResponse>> joinRequests(@AuthenticationPrincipal Jwt jwt,@PathVariable Long groupId,@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size){return ApiResponse.success(service.joinRequests(groupId,uid(jwt),page,size));}
    @PostMapping("/{groupId}/join-requests/{memberId}/approve") public ApiResponse<GroupMemberResponse> approve(@AuthenticationPrincipal Jwt jwt,@PathVariable Long groupId,@PathVariable Long memberId){return ApiResponse.success(service.respondJoin(groupId,uid(jwt),memberId,true));}
    @PostMapping("/{groupId}/join-requests/{memberId}/reject") public ApiResponse<GroupMemberResponse> reject(@AuthenticationPrincipal Jwt jwt,@PathVariable Long groupId,@PathVariable Long memberId){return ApiResponse.success(service.respondJoin(groupId,uid(jwt),memberId,false));}
    @GetMapping("/{groupId}/members") public ApiResponse<PagedResponse<GroupMemberResponse>> members(@AuthenticationPrincipal Jwt jwt,@PathVariable Long groupId,@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size){return ApiResponse.success(service.activeMembers(groupId,uid(jwt),page,size));}
    @DeleteMapping("/{groupId}/members/me") public ApiResponse<Boolean> leave(@AuthenticationPrincipal Jwt jwt,@PathVariable Long groupId){service.leave(groupId,uid(jwt));return ApiResponse.success(true);}
    @DeleteMapping("/{groupId}/members/{userId}") public ApiResponse<Boolean> remove(@AuthenticationPrincipal Jwt jwt,@PathVariable Long groupId,@PathVariable Long userId){service.remove(groupId,uid(jwt),userId);return ApiResponse.success(true);}
    private Long uid(Jwt jwt){return Long.valueOf(jwt.getSubject());}
}
