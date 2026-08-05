package com.lifequest.group.dto;
import com.lifequest.group.GroupVisibility;
import jakarta.validation.constraints.*;
public record UpdateGroupRequest(@NotBlank @Size(min=2,max=100) String name,@NotBlank @Size(max=500) String description,@NotNull GroupVisibility visibility,@Min(2) @Max(100) int maxMembers) {}
