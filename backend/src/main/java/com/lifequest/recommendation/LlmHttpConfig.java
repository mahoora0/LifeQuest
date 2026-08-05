package com.lifequest.recommendation;
import org.springframework.context.annotation.Bean;import org.springframework.context.annotation.Configuration;import org.springframework.web.client.RestClient;
@Configuration
class LlmHttpConfig {
 @Bean RestClient.Builder llmRestClientBuilder(){return RestClient.builder();}
}
