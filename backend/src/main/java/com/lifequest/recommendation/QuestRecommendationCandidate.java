package com.lifequest.recommendation;

/**
 * 앱으로 나가는 추천 후보 한 건.
 *
 * <p>{@code candidateId}는 <b>주간 추천에서만 채워진다.</b> 일반 place/travel 추천은 후보를
 * 저장하지 않으므로 {@code null}이며, 앱은 이 값이 있을 때만 "퀘스트로 받기"를 띄운다.
 * 선택 요청이 후보 내용을 되돌려 보내지 않고 이 id만 보내는 것이 핵심이다 —
 * 그래야 제목·완료 가이드를 앱에서 바꿔 보내는 경로가 없다.
 */
public record QuestRecommendationCandidate(
    int index,
    Long candidateId,
    RecommendationType recommendationType,
    String title,
    String description,
    RecommendationCategory category,
    int durationValue,
    DurationUnit durationUnit,
    int estimatedCostPerPerson,
    String suggestedPlaceName,
    String completionGuide) {
}
