package com.lifequest.recommendation;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.lifequest.auth.AuthService;
import com.lifequest.auth.dto.LoginRequest;
import com.lifequest.auth.dto.SignupRequest;
import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
class QuestRecommendationHttpIntegrationTests {

    @Autowired MockMvc mockMvc;
    @Autowired AuthService auth;
    @MockitoBean RoutingQuestRecommendationProvider provider;

    @BeforeEach
    void configureProvider() {
        reset(provider);
        when(provider.selected()).thenReturn(LlmProvider.OPENAI);
        when(provider.model()).thenReturn("gpt-test");
        when(provider.generate(any(), anyString(), anyString()))
                .thenAnswer(invocation -> candidates(invocation.getArgument(0)));
    }

    @Test
    void placeAndTravelRequestsReturnThreeValidatedCandidates() throws Exception {
        String token=token("recommendSuccess");

        mockMvc.perform(post("/api/quest-recommendations/place")
                        .header("Authorization","Bearer "+token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(placeRequest()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.provider").value("OPENAI"))
                .andExpect(jsonPath("$.data.model").value("gpt-test"))
                .andExpect(jsonPath("$.data.remainingRequestsToday").value(9))
                .andExpect(jsonPath("$.data.candidates.length()").value(3))
                .andExpect(jsonPath("$.data.candidates[0].recommendationType").value("PLACE"));

        mockMvc.perform(post("/api/quest-recommendations/travel")
                        .header("Authorization","Bearer "+token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(travelRequest()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.remainingRequestsToday").value(8))
                .andExpect(jsonPath("$.data.candidates.length()").value(3))
                .andExpect(jsonPath("$.data.candidates[0].recommendationType").value("TRAVEL"));
    }

    @Test
    void authenticationAndInputValidationUseTheCommonErrorEnvelope() throws Exception {
        mockMvc.perform(post("/api/quest-recommendations/place")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(placeRequest()))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));

        String token=token("recommendInvalid");
        reset(provider);
        mockMvc.perform(post("/api/quest-recommendations/place")
                        .header("Authorization","Bearer "+token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"area":" ","availableMinutes":10,"budgetPerPerson":-1,
                                 "companionCount":0,"environment":"ANY","interests":[]}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("VALIDATION_FAILED"));
        verifyNoInteractions(provider);
    }

    @Test
    void providerFailuresAreMappedToStableHttpErrors() throws Exception {
        String token=token("recommendTimeout");
        when(provider.generate(any(),anyString(),anyString()))
                .thenThrow(new BusinessException(ErrorCode.LLM_PROVIDER_TIMEOUT));

        mockMvc.perform(post("/api/quest-recommendations/place")
                        .header("Authorization","Bearer "+token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(placeRequest()))
                .andExpect(status().isGatewayTimeout())
                .andExpect(jsonPath("$.error.code").value("LLM_PROVIDER_TIMEOUT"));
    }

    @Test
    void eleventhHttpRequestIsRejectedBeforeCallingTheProvider() throws Exception {
        String token=token("recommendLimit");
        for(int request=1;request<=10;request++) {
            mockMvc.perform(post("/api/quest-recommendations/place")
                            .header("Authorization","Bearer "+token)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(placeRequest()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.remainingRequestsToday").value(10-request));
        }

        mockMvc.perform(post("/api/quest-recommendations/place")
                        .header("Authorization","Bearer "+token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(placeRequest()))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.error.code").value("LLM_DAILY_LIMIT_EXCEEDED"));
    }

    private String token(String prefix) {
        String suffix=UUID.randomUUID().toString().substring(0,8);
        String email=prefix+suffix+"@lifequest.test";
        auth.signup(new SignupRequest(email,"password123",prefix+suffix));
        return auth.login(new LoginRequest(email,"password123")).accessToken();
    }

    private String placeRequest() {
        return """
                {"area":"서울 성수동","availableMinutes":180,"budgetPerPerson":30000,
                 "companionCount":2,"environment":"ANY","interests":["산책","전시"],
                 "additionalRequest":"조용한 활동"}
                """;
    }

    private String travelRequest() {
        return """
                {"destination":"부산","days":2,"budgetPerPerson":200000,
                 "companionCount":2,"interests":["바다","음식"],"additionalRequest":"대중교통 위주"}
                """;
    }

    private List<QuestRecommendationCandidate> candidates(RecommendationType type) {
        DurationUnit unit=type==RecommendationType.PLACE?DurationUnit.MINUTES:DurationUnit.DAYS;
        int duration=type==RecommendationType.PLACE?120:2;
        return List.of(
                candidate(1,type,unit,duration),
                candidate(2,type,unit,duration),
                candidate(3,type,unit,duration));
    }

    private QuestRecommendationCandidate candidate(int index,RecommendationType type,DurationUnit unit,int duration) {
        return new QuestRecommendationCandidate(index,null,type,"추천 "+index,"충분히 구체적인 추천 설명입니다 "+index,
                RecommendationCategory.CULTURE,duration,unit,10000,"추천 장소 "+index,"현장에서 경험을 완료하고 기록하세요 "+index);
    }
}
