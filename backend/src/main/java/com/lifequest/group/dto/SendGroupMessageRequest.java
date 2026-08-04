package com.lifequest.group.dto;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
public record SendGroupMessageRequest(@NotBlank @Size(max=1000) String content) {}
