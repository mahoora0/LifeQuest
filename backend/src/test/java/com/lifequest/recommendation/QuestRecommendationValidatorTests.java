package com.lifequest.recommendation;
import static org.assertj.core.api.Assertions.*;import com.lifequest.common.exception.*;import java.util.*;import org.junit.jupiter.api.Test;
class QuestRecommendationValidatorTests {
 private final QuestRecommendationValidator validator=new QuestRecommendationValidator();
 @Test void normalizesIndexesAndRejectsDuplicateOrOverBudgetCandidates(){var valid=List.of(candidate("첫 번째",1000),candidate("두 번째",2000),candidate("세 번째",3000));assertThat(validator.validate(valid,new RecommendationConstraints(RecommendationType.PLACE,3000,180))).extracting(QuestRecommendationCandidate::index).containsExactly(1,2,3);var invalid=List.of(candidate("중복",1000),candidate("중복",1000),candidate("세 번째",4000));assertThatThrownBy(()->validator.validate(invalid,new RecommendationConstraints(RecommendationType.PLACE,3000,180))).isInstanceOfSatisfying(BusinessException.class,e->assertThat(e.errorCode()).isEqualTo(ErrorCode.LLM_INVALID_RESPONSE));}
 private QuestRecommendationCandidate candidate(String title,int cost){return new QuestRecommendationCandidate(0,RecommendationType.PLACE,title,"실제로 수행할 수 있는 충분히 긴 설명입니다",RecommendationCategory.CULTURE,120,DurationUnit.MINUTES,cost,"성수동 전시 공간","현장에서 활동을 완료한 뒤 기록하세요");}
}
