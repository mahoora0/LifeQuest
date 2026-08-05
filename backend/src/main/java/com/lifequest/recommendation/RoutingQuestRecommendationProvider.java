package com.lifequest.recommendation;
import com.lifequest.common.exception.*;import java.util.*;import org.springframework.stereotype.Component;
@Component
public class RoutingQuestRecommendationProvider {
 private final LlmProperties properties;private final Map<LlmProvider,QuestRecommendationProvider> providers;
 public RoutingQuestRecommendationProvider(LlmProperties properties,List<QuestRecommendationProvider> providers){this.properties=properties;this.providers=new EnumMap<>(LlmProvider.class);providers.forEach(p->this.providers.put(p.provider(),p));}
 public LlmProvider selected(){try{return LlmProvider.valueOf(properties.getProvider()==null?"":properties.getProvider().trim().toUpperCase());}catch(Exception e){throw new BusinessException(ErrorCode.LLM_NOT_CONFIGURED);}}
 public String model(){LlmProvider p=selected();LlmProperties.Provider config=properties.selected(p);OpenAiQuestRecommendationProvider.configured(config);return config.getModel();}
 public List<QuestRecommendationCandidate> generate(RecommendationType type,String instruction,String prompt){LlmProvider p=selected();model();QuestRecommendationProvider provider=providers.get(p);if(provider==null)throw new BusinessException(ErrorCode.LLM_NOT_CONFIGURED);return provider.generate(type,instruction,prompt);}
}
