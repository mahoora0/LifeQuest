package com.lifequest.recommendation;
import com.lifequest.common.exception.*;import com.lifequest.recommendation.dto.*;import java.util.*;import org.springframework.dao.DataIntegrityViolationException;import org.springframework.stereotype.Service;
@Service
public class QuestRecommendationService {
 private final RoutingQuestRecommendationProvider provider;private final QuestRecommendationPromptFactory prompts;private final QuestRecommendationValidator validator;private final QuestRecommendationUsageService usage;
 public QuestRecommendationService(RoutingQuestRecommendationProvider provider,QuestRecommendationPromptFactory prompts,QuestRecommendationValidator validator,QuestRecommendationUsageService usage){this.provider=provider;this.prompts=prompts;this.validator=validator;this.usage=usage;}
 public QuestRecommendationResponse place(Long userId,PlaceQuestRecommendationRequest r){validatePlace(r);return toResponse(run(userId,prompts.place(r),new RecommendationConstraints(RecommendationType.PLACE,r.budgetPerPerson(),r.availableMinutes())));}
 public QuestRecommendationResponse travel(Long userId,TravelQuestRecommendationRequest r){validateTravel(r,MAX_TRAVEL_DAYS);return toResponse(run(userId,prompts.travel(r),new RecommendationConstraints(RecommendationType.TRAVEL,r.budgetPerPerson(),r.days())));}

 /** 일반 여행 추천의 최대 기간. 주간 퀘스트 모드는 이 값이 아니라 그 주의 남은 일수를 쓴다. */
 static final int MAX_TRAVEL_DAYS=14;

 /** 한 번의 추천 생성 결과. 주간 경로가 후보를 저장해야 해서 응답 조립 전 단계를 따로 둔다. */
 record Generated(LlmProvider provider,String model,int remaining,List<QuestRecommendationCandidate> candidates){}

 static QuestRecommendationResponse toResponse(Generated g){return new QuestRecommendationResponse(g.provider(),g.model(),g.remaining(),g.candidates());}

 /**
  * 사용량 차감 → LLM 호출 → 응답 검증.
  *
  * <p><b>차감이 호출보다 먼저다.</b> LLM 호출이 실패해도 차감은 남는다({@code REQUIRES_NEW}) —
  * 실패를 반복해 한도를 우회하는 경로를 막기 위한 것이다. 그래서 <b>호출 자격 검사는 이 메서드에
  * 들어오기 전에 끝나 있어야 한다</b>. 쓸 수도 없는 추천 때문에 하루 횟수를 잃으면 안 된다
  * ({@link WeeklyQuestRecommendationService}의 Lv.3 검사가 그 이유로 앞에 있다).
  */
 Generated run(Long userId,String prompt,RecommendationConstraints constraints){
  LlmProvider selected=provider.selected();String model=provider.model();
  int remaining;try{remaining=usage.consume(userId);}catch(DataIntegrityViolationException first){remaining=usage.consume(userId);}
  List<QuestRecommendationCandidate> result=provider.generate(constraints.type(),QuestRecommendationPromptFactory.SYSTEM_INSTRUCTION,prompt);
  return new Generated(selected,model,remaining,validator.validate(result,constraints));
 }

 void validatePlace(PlaceQuestRecommendationRequest r){if(r==null||invalidText(r.area(),2,100)||r.availableMinutes()==null||r.availableMinutes()<30||r.availableMinutes()>720||r.budgetPerPerson()==null||r.budgetPerPerson()<0||r.budgetPerPerson()>10000000||r.companionCount()==null||r.companionCount()<1||r.companionCount()>20||r.environment()==null)invalid();common(r.interests(),r.additionalRequest());}
 /** @param maxDays 허용 최대 기간. 일반 추천은 14일, 주간 퀘스트 모드는 그 주의 남은 일수다. */
 void validateTravel(TravelQuestRecommendationRequest r,int maxDays){if(r==null||invalidText(r.destination(),2,100)||r.days()==null||r.days()<1||r.days()>maxDays||r.budgetPerPerson()==null||r.budgetPerPerson()<0||r.budgetPerPerson()>50000000||r.companionCount()==null||r.companionCount()<1||r.companionCount()>20)invalid();common(r.interests(),r.additionalRequest());}
 private void common(List<String> interests,String request){if(interests!=null&&(interests.size()>5||interests.stream().anyMatch(i->invalidText(i,1,30)))||request!=null&&request.trim().length()>500)invalid();}
 private boolean invalidText(String v,int min,int max){return v==null||v.trim().length()<min||v.trim().length()>max;}private void invalid(){throw new BusinessException(ErrorCode.VALIDATION_FAILED);}
}
