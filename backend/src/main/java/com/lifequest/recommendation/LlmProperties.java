package com.lifequest.recommendation;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;
@Component @ConfigurationProperties(prefix="app.llm")
public class LlmProperties {
    private String provider="";private int requestTimeoutSeconds=30;private int dailyRequestLimit=10;private Provider openai=new Provider();private Provider gemini=new Provider();
    public String getProvider(){return provider;}public void setProvider(String v){provider=v;}public int getRequestTimeoutSeconds(){return requestTimeoutSeconds;}public void setRequestTimeoutSeconds(int v){requestTimeoutSeconds=v;}public int getDailyRequestLimit(){return dailyRequestLimit;}public void setDailyRequestLimit(int v){dailyRequestLimit=v;}public Provider getOpenai(){return openai;}public void setOpenai(Provider v){openai=v;}public Provider getGemini(){return gemini;}public void setGemini(Provider v){gemini=v;}
    public Provider selected(LlmProvider p){return p==LlmProvider.OPENAI?openai:gemini;}
    public static class Provider {private String apiKey="";private String model="";public String getApiKey(){return apiKey;}public void setApiKey(String v){apiKey=v;}public String getModel(){return model;}public void setModel(String v){model=v;}}
}
