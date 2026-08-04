package com.lifequest.recommendation;
import tools.jackson.databind.*;import com.lifequest.common.exception.*;import java.time.Duration;import java.util.*;import org.springframework.http.client.JdkClientHttpRequestFactory;import org.springframework.stereotype.Component;import org.springframework.web.client.RestClient;
@Component
public class OpenAiQuestRecommendationProvider implements QuestRecommendationProvider {
 private final LlmProperties properties;private final ObjectMapper mapper;private final RestClient client;
 @org.springframework.beans.factory.annotation.Autowired public OpenAiQuestRecommendationProvider(LlmProperties properties,ObjectMapper mapper,RestClient.Builder builder){this.properties=properties;this.mapper=mapper;JdkClientHttpRequestFactory f=new JdkClientHttpRequestFactory();f.setReadTimeout(Duration.ofSeconds(Math.max(1,properties.getRequestTimeoutSeconds())));this.client=builder.clone().requestFactory(f).baseUrl("https://api.openai.com").build();}
 OpenAiQuestRecommendationProvider(LlmProperties properties,ObjectMapper mapper,RestClient client){this.properties=properties;this.mapper=mapper;this.client=client;}
 public LlmProvider provider(){return LlmProvider.OPENAI;}
 public List<QuestRecommendationCandidate> generate(RecommendationType type,String instructions,String input){
  var config=properties.getOpenai();configured(config);Map<String,Object> format=new LinkedHashMap<>();format.put("type","json_schema");format.put("name","lifequest_recommendations");format.put("strict",true);format.put("schema",QuestRecommendationSchema.value());
  try{String body=client.post().uri("/v1/responses").header("Authorization","Bearer "+config.getApiKey()).body(Map.of("model",config.getModel(),"instructions",instructions,"input",input,"text",Map.of("format",format))).retrieve().body(String.class);JsonNode root=mapper.readTree(body);for(JsonNode output:root.path("output"))if("message".equals(output.path("type").asText()))for(JsonNode content:output.path("content"))if("output_text".equals(content.path("type").asText()))return QuestRecommendationJson.parse(mapper,content.path("text").asText());throw new BusinessException(ErrorCode.LLM_INVALID_RESPONSE);}catch(BusinessException e){throw e;}catch(Exception e){throw ProviderHttpSupport.map(e);}
 }
 static void configured(LlmProperties.Provider p){if(p==null||p.getApiKey()==null||p.getApiKey().isBlank()||p.getModel()==null||p.getModel().isBlank())throw new BusinessException(ErrorCode.LLM_NOT_CONFIGURED);}
}
