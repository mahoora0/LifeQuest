package com.lifequest.recommendation;

import static org.assertj.core.api.Assertions.*;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.*;
import static org.springframework.test.web.client.response.MockRestResponseCreators.*;

import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;

class QuestRecommendationProviderTests {
    private final ObjectMapper mapper = JsonMapper.builder().build();

    @Test
    void openAiUsesResponsesStructuredOutputAndParsesOutputText() throws Exception {
        LlmProperties p=properties();RestClient.Builder builder=RestClient.builder().baseUrl("https://api.openai.com");MockRestServiceServer server=MockRestServiceServer.bindTo(builder).build();
        server.expect(requestTo("https://api.openai.com/v1/responses")).andExpect(header("Authorization","Bearer test-key")).andExpect(content().string(org.hamcrest.Matchers.containsString("\"json_schema\""))).andRespond(withSuccess(mapper.writeValueAsString(Map.of("output",List.of(Map.of("type","message","content",List.of(Map.of("type","output_text","text",candidateJson(RecommendationType.PLACE,DurationUnit.MINUTES,120))))))),MediaType.APPLICATION_JSON));
        var provider=new OpenAiQuestRecommendationProvider(p,mapper,builder.build());
        assertThat(provider.generate(RecommendationType.PLACE,"system","input")).hasSize(3);server.verify();
    }

    @Test
    void geminiUsesGenerateContentAndParsesTextPart() throws Exception {
        LlmProperties p=properties();p.getGemini().setApiKey("gemini-key");p.getGemini().setModel("gemini-test");RestClient.Builder builder=RestClient.builder().baseUrl("https://generativelanguage.googleapis.com");MockRestServiceServer server=MockRestServiceServer.bindTo(builder).build();
        server.expect(requestTo("https://generativelanguage.googleapis.com/v1beta/models/gemini-test:generateContent")).andExpect(header("x-goog-api-key","gemini-key")).andExpect(content().string(org.hamcrest.Matchers.containsString("responseSchema"))).andRespond(withSuccess(mapper.writeValueAsString(Map.of("candidates",List.of(Map.of("content",Map.of("parts",List.of(Map.of("text",candidateJson(RecommendationType.TRAVEL,DurationUnit.DAYS,2)))))))),MediaType.APPLICATION_JSON));
        var provider=new GeminiQuestRecommendationProvider(p,mapper,builder.build());
        assertThat(provider.generate(RecommendationType.TRAVEL,"system","input")).hasSize(3);server.verify();
    }

    private LlmProperties properties(){LlmProperties p=new LlmProperties();p.getOpenai().setApiKey("test-key");p.getOpenai().setModel("gpt-test");return p;}
    private String candidateJson(RecommendationType type,DurationUnit unit,int duration) throws Exception {List<Map<String,Object>> items=new ArrayList<>();for(int i=1;i<=3;i++)items.add(Map.of("recommendationType",type.name(),"title","추천 "+i,"description","충분히 긴 추천 설명입니다 "+i,"category","CULTURE","durationValue",duration,"durationUnit",unit.name(),"estimatedCostPerPerson",1000,"suggestedPlaceName","추천 장소 "+i,"completionGuide","현장에서 활동을 완료하세요 "+i));return mapper.writeValueAsString(Map.of("candidates",items));}
}
