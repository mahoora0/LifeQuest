package com.lifequest.recommendation;
import static org.assertj.core.api.Assertions.*;import com.lifequest.auth.*;import com.lifequest.auth.dto.*;import com.lifequest.common.exception.*;import com.lifequest.user.*;import java.util.UUID;import org.junit.jupiter.api.Test;import org.springframework.beans.factory.annotation.Autowired;import org.springframework.boot.test.context.SpringBootTest;import org.springframework.test.context.ActiveProfiles;
@SpringBootTest @ActiveProfiles("test")
class QuestRecommendationUsageIntegrationTests {
 @Autowired AuthService auth;@Autowired UserRepository users;@Autowired QuestRecommendationUsageService usage;
 @Test void eleventhRequestIsRejected(){String token=UUID.randomUUID().toString().substring(0,8);String email="usage"+token+"@lifequest.test";auth.signup(new SignupRequest(email,"password123","usage"+token));Long id=users.findByEmailIgnoreCase(email).orElseThrow().getId();for(int i=9;i>=0;i--)assertThat(usage.consume(id)).isEqualTo(i);assertThatThrownBy(()->usage.consume(id)).isInstanceOfSatisfying(BusinessException.class,e->assertThat(e.errorCode()).isEqualTo(ErrorCode.LLM_DAILY_LIMIT_EXCEEDED));}
}
