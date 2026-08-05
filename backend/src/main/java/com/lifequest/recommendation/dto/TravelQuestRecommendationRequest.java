package com.lifequest.recommendation.dto;
import jakarta.validation.constraints.*;import java.util.List;
public record TravelQuestRecommendationRequest(@NotBlank @Size(min=2,max=100) String destination,@NotNull @Min(1) @Max(14) Integer days,@NotNull @Min(0) @Max(50000000) Integer budgetPerPerson,@NotNull @Min(1) @Max(20) Integer companionCount,@Size(max=5) List<@NotBlank @Size(max=30) String> interests,@Size(max=500) String additionalRequest) {}
