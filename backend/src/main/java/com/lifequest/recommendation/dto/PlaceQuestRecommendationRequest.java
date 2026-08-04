package com.lifequest.recommendation.dto;
import com.lifequest.recommendation.RecommendationEnvironment;import jakarta.validation.Valid;import jakarta.validation.constraints.*;import java.util.List;
public record PlaceQuestRecommendationRequest(@NotBlank @Size(min=2,max=100) String area,@NotNull @Min(30) @Max(720) Integer availableMinutes,@NotNull @Min(0) @Max(10000000) Integer budgetPerPerson,@NotNull @Min(1) @Max(20) Integer companionCount,@NotNull RecommendationEnvironment environment,@Size(max=5) List<@NotBlank @Size(max=30) String> interests,@Size(max=500) String additionalRequest) {}
