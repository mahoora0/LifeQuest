package com.lifequest.group.dto;
import jakarta.validation.constraints.*;
import java.time.LocalDateTime;
public record CreateGroupQuestRequest(@NotBlank @Size(min=2,max=100) String title,@NotBlank @Size(max=1000) String description,@NotBlank @Size(max=200) String placeName,@NotNull LocalDateTime scheduledAt,@Min(2) @Max(100) Integer maxParticipants) {}
