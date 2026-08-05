package com.lifequest.recommendation;
import tools.jackson.databind.*;import com.lifequest.common.exception.*;import java.time.Duration;import java.util.*;import org.springframework.http.client.JdkClientHttpRequestFactory;import org.springframework.stereotype.Component;import org.springframework.web.client.RestClient;
@Component
public class GeminiQuestRecommendationProvider implements QuestRecommendationProvider {
 private final LlmProperties properties;private final ObjectMapper mapper;private final RestClient client;
 @org.springframework.beans.factory.annotation.Autowired public GeminiQuestRecommendationProvider(LlmProperties properties,ObjectMapper mapper,RestClient.Builder builder){this.properties=properties;this.mapper=mapper;JdkClientHttpRequestFactory f=new JdkClientHttpRequestFactory();f.setReadTimeout(Duration.ofSeconds(Math.max(1,properties.getRequestTimeoutSeconds())));client=builder.clone().requestFactory(f).baseUrl("https://generativelanguage.googleapis.com").build();}
 GeminiQuestRecommendationProvider(LlmProperties properties,ObjectMapper mapper,RestClient client){this.properties=properties;this.mapper=mapper;this.client=client;}
 public LlmProvider provider(){return LlmProvider.GEMINI;}
 public List<QuestRecommendationCandidate> generate(RecommendationType type,String instructions,String input){
  var config=properties.getGemini();OpenAiQuestRecommendationProvider.configured(config);Map<String,Object> body=Map.of("systemInstruction",Map.of("parts",List.of(Map.of("text",instructions))),"contents",List.of(Map.of("role","user","parts",List.of(Map.of("text",input)))),"generationConfig",Map.of("responseMimeType","application/json","responseSchema",QuestRecommendationSchema.value()));
  try{String raw=client.post().uri("/v1beta/models/{model}:generateContent",config.getModel()).header("x-goog-api-key",config.getApiKey()).body(body).retrieve().body(String.class);JsonNode root=mapper.readTree(raw);String text=root.path("candidates").path(0).path("content").path("parts").path(0).path("text").asText(null);if(text==null)throw new BusinessException(ErrorCode.LLM_INVALID_RESPONSE);return QuestRecommendationJson.parse(mapper,text);}catch(BusinessException e){throw e;}catch(Exception e){throw ProviderHttpSupport.map(e);}
 }
}
