package com.lifequest.recommendation;
import java.util.List;
public interface QuestRecommendationProvider {
    LlmProvider provider();
    List<QuestRecommendationCandidate> generate(RecommendationType type,String systemInstruction,String userPrompt);
}
