package com.lifequest.group;
import com.lifequest.common.response.ApiResponse;
import com.lifequest.group.dto.*;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/groups/{groupId}/messages")
public class GroupChatController {
    private final GroupChatService service;public GroupChatController(GroupChatService service){this.service=service;}
    @GetMapping public ApiResponse<GroupMessagePageResponse> get(@AuthenticationPrincipal Jwt jwt,@PathVariable Long groupId,@RequestParam(required=false) Long beforeId,@RequestParam(required=false) Long afterId,@RequestParam(defaultValue="50") int size){return ApiResponse.success(service.get(groupId,uid(jwt),beforeId,afterId,size));}
    @PostMapping public ApiResponse<GroupMessageResponse> send(@AuthenticationPrincipal Jwt jwt,@PathVariable Long groupId,@Valid @RequestBody SendGroupMessageRequest r){return ApiResponse.success(service.send(groupId,uid(jwt),r.content()));}
    private Long uid(Jwt jwt){return Long.valueOf(jwt.getSubject());}
}
