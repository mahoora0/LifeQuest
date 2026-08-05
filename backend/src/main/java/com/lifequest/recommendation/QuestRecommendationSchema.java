package com.lifequest.recommendation;
import java.util.*;
public final class QuestRecommendationSchema {
 private QuestRecommendationSchema(){}
 public static Map<String,Object> value(){
  Map<String,Object> item=new LinkedHashMap<>();item.put("type","object");item.put("additionalProperties",false);
  item.put("properties",Map.of(
   "recommendationType",Map.of("type","string","enum",List.of("PLACE","TRAVEL")),"title",Map.of("type","string"),"description",Map.of("type","string"),
   "category",Map.of("type","string","enum",List.of("FOOD","CAFE","WALK","NATURE","CULTURE","EXERCISE","EXPERIENCE","TRAVEL")),"durationValue",Map.of("type","integer"),
   "durationUnit",Map.of("type","string","enum",List.of("MINUTES","DAYS")),"estimatedCostPerPerson",Map.of("type","integer"),"suggestedPlaceName",Map.of("type","string"),"completionGuide",Map.of("type","string")));
  item.put("required",List.of("recommendationType","title","description","category","durationValue","durationUnit","estimatedCostPerPerson","suggestedPlaceName","completionGuide"));
  Map<String,Object> candidates=new LinkedHashMap<>();candidates.put("type","array");candidates.put("minItems",3);candidates.put("maxItems",3);candidates.put("items",item);
  Map<String,Object> root=new LinkedHashMap<>();root.put("type","object");root.put("additionalProperties",false);root.put("properties",Map.of("candidates",candidates));root.put("required",List.of("candidates"));return root;
 }
}
