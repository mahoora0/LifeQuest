package com.lifequest.recommendation;
public record QuestRecommendationCandidate(int index,RecommendationType recommendationType,String title,String description,RecommendationCategory category,int durationValue,DurationUnit durationUnit,int estimatedCostPerPerson,String suggestedPlaceName,String completionGuide) {}
