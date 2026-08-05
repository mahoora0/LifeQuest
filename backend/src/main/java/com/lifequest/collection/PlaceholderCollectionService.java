package com.lifequest.collection;

import org.springframework.stereotype.Service;

/**
 * 팀원 3의 실제 LifeDex·업적 판정 로직이 들어오기 전까지의 자리표시자. 항상 빈 결과만 돌려준다 — 도감
 * 등록도 업적 해금도 일어나지 않는다.
 *
 * <p><b>회수 신호:</b> 팀원 3이 {@link CollectionService}의 실제 구현체를 {@code @Service}로 추가하면
 * 빈 후보가 둘이 되어 {@code NoUniqueBeanDefinitionException}으로 애플리케이션 컨텍스트 로딩이 실패한다.
 * 그 실패가 이 클래스를 지우라는 신호다.
 *
 * <p><b>회수 방법은 이 파일을 삭제하는 것 하나뿐이다.</b> 위 예외를 {@code @Primary}·{@code @Qualifier}·
 * {@code @ConditionalOnMissingBean}으로 덮으면 컨텍스트는 뜨지만 자리표시자가 살아남는다. 그러면 실구현이
 * 있는데도 도감·업적이 영구히 빈 결과가 되고, 완료 응답의 {@code collection}이 항상 비어 해금 모달도
 * 뜨지 않는다 — 예외가 사라져 실패가 조용해지므로 CI로도 잡히지 않는다.
 */
@Service
class PlaceholderCollectionService implements CollectionService {

    @Override
    public CollectionOutcome evaluateOnQuestCompletion(
            Long userId, Long questId, Long lifedexItemId, Long questCompletionId) {
        return CollectionOutcome.none();
    }
}
