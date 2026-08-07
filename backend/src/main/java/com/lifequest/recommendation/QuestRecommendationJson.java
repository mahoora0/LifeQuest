package com.lifequest.recommendation;
import tools.jackson.databind.*;import com.lifequest.common.exception.*;import java.util.*;
public final class QuestRecommendationJson {
 private QuestRecommendationJson(){}
 public static List<QuestRecommendationCandidate> parse(ObjectMapper mapper,String json){
  try{JsonNode items=mapper.readTree(json).path("candidates");if(!items.isArray())throw new IllegalArgumentException();List<QuestRecommendationCandidate> result=new ArrayList<>();for(JsonNode n:items)result.add(new QuestRecommendationCandidate(0,null,RecommendationType.valueOf(n.path("recommendationType").asText()),n.path("title").asText(),n.path("description").asText(),RecommendationCategory.valueOf(n.path("category").asText()),n.path("durationValue").intValue(),DurationUnit.valueOf(n.path("durationUnit").asText()),n.path("estimatedCostPerPerson").intValue(),n.path("suggestedPlaceName").asText(),n.path("completionGuide").asText()));return result;}catch(Exception e){throw new BusinessException(ErrorCode.LLM_INVALID_RESPONSE);}
 }
}
