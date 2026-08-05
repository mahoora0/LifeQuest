package com.lifequest.recommendation.dto;
import com.lifequest.recommendation.*;import java.util.List;
public record QuestRecommendationResponse(LlmProvider provider,String model,int remainingRequestsToday,List<QuestRecommendationCandidate> candidates) {}
