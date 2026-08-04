package com.lifequest.recommendation;
import com.lifequest.common.exception.*;import com.lifequest.user.*;import java.time.*;import org.springframework.stereotype.Service;import org.springframework.transaction.annotation.*;
@Service
public class QuestRecommendationUsageService {
 private final QuestRecommendationUsageRepository usages;private final UserRepository users;private final LlmProperties properties;private final Clock clock;
 public QuestRecommendationUsageService(QuestRecommendationUsageRepository usages,UserRepository users,LlmProperties properties,Clock clock){this.usages=usages;this.users=users;this.properties=properties;this.clock=clock;}
 @Transactional(propagation=Propagation.REQUIRES_NEW) public int consume(Long userId){int limit=properties.getDailyRequestLimit();if(limit<1)throw new BusinessException(ErrorCode.LLM_NOT_CONFIGURED);LocalDateTime now=LocalDateTime.now(clock);LocalDate date=now.minusHours(4).toLocalDate();QuestRecommendationUsage usage=usages.findForUpdate(userId,date).orElse(null);if(usage==null){User user=users.findById(userId).orElseThrow(()->new BusinessException(ErrorCode.RESOURCE_NOT_FOUND));usages.saveAndFlush(new QuestRecommendationUsage(user,date,now));return limit-1;}if(usage.getRequestCount()>=limit)throw new BusinessException(ErrorCode.LLM_DAILY_LIMIT_EXCEEDED);usage.increment(now);return limit-usage.getRequestCount();}
}
