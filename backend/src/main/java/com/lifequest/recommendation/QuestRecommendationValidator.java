package com.lifequest.recommendation;
import com.lifequest.common.exception.*;import java.util.*;import org.springframework.stereotype.Component;
@Component
public class QuestRecommendationValidator {
 public List<QuestRecommendationCandidate> validate(List<QuestRecommendationCandidate> input,RecommendationConstraints c){
  if(input==null||input.size()!=3)fail();Set<String> titles=new HashSet<>();List<QuestRecommendationCandidate> result=new ArrayList<>();int index=1;
  for(QuestRecommendationCandidate q:input){String title=text(q.title(),2,100);String description=text(q.description(),10,500);String place=text(q.suggestedPlaceName(),2,100);String guide=text(q.completionGuide(),5,300);if(!titles.add(title.toLowerCase(Locale.ROOT))||q.recommendationType()!=c.type()||q.estimatedCostPerPerson()<0||q.estimatedCostPerPerson()>c.budget()||q.durationValue()<1)fail();if(c.type()==RecommendationType.PLACE&&(q.durationUnit()!=DurationUnit.MINUTES||q.durationValue()>c.duration()))fail();if(c.type()==RecommendationType.TRAVEL&&(q.durationUnit()!=DurationUnit.DAYS||q.durationValue()!=c.duration()))fail();if(q.category()==null)fail();result.add(new QuestRecommendationCandidate(index++,q.recommendationType(),title,description,q.category(),q.durationValue(),q.durationUnit(),q.estimatedCostPerPerson(),place,guide));}return List.copyOf(result);
 }
 private String text(String s,int min,int max){String v=s==null?"":s.trim();if(v.length()<min||v.length()>max)fail();return v;}private void fail(){throw new BusinessException(ErrorCode.LLM_INVALID_RESPONSE);}
}
