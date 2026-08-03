package com.lifequest.collection;

import org.springframework.stereotype.Service;

/**
 * 팀원 3의 실제 LifeDex·업적 판정 로직이 들어오기 전까지의 자리표시자. 항상 빈 결과만 돌려준다 — 도감
 * 등록도 업적 해금도 일어나지 않는다.
 *
 * <p><b>회수 신호:</b> 팀원 3이 {@link CollectionService}의 실제 구현체를 {@code @Service}로 추가하면
 * 빈 후보가 둘이 되어 {@code NoUniqueBeanDefinitionException}으로 애플리케이션 컨텍스트 로딩이 실패한다.
 * 그 실패가 이 클래스를 지우라는 신호다.
 */
@Service
class PlaceholderCollectionService implements CollectionService {

    @Override
    public CollectionOutcome evaluateOnQuestCompletion(
            Long userId, Long questId, Long lifedexItemId, Long questCompletionId) {
        return CollectionOutcome.none();
    }
}
