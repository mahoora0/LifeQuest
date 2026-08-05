package com.lifequest.collection;

import com.lifequest.growth.RewardGrant;
import java.util.List;

/**
 * 퀘스트 완료 한 번으로 새로 얻은 도감 항목·업적. {@code com.lifequest.quest.dto.QuestCompletionResponse
 * .CollectionResult}와 필드가 같아 보이지만, quest DTO를 그대로 반환하면 collection 모듈이 quest에
 * 역방향 의존하게 되어 전용 타입을 둔다(같은 이유로 {@code GrowthSnapshot}이 분리된 전례가 있다).
 */
public record CollectionOutcome(List<Entry> newLifedexItems, List<Entry> newAchievements) {

    /**
     * @param secret 비밀 업적인지. 도감 항목에는 해당하지 않아 항상 {@code false}. 앱은 이 값 하나로 완료 결과
     *     화면 위에 해금 모달({@code secret_achievement_modal.dart}, 화면 S-17)을 겹칠지 정한다 — 비밀 업적을
     *     해금했는데 {@code false}로 오면 모달이 한 번도 뜨지 않고, 그 실패는 예외도 로그도 남기지 않는다.
     * @param reward 이 항목을 얻으며 함께 지급된 보상. 없으면 {@code null}이며, {@code null}의 의미가 둘이라
     *     구분해서 봐야 한다 — 도감 항목({@code newLifedexItems})은 보상 개념이 없어 <em>항상</em>
     *     {@code null}이고, 업적({@code newAchievements})은 {@code ACHIEVEMENT_STEPS.reward_title_id}가
     *     비어 있거나 <em>지급이 아직 구현되지 않았을 때</em> {@code null}이다. 뒤쪽은 임시 상태이며
     *     {@code QuestCompletionContractTests}의 비밀 업적 계약이 그 회수를 강제한다.
     *     <p>레벨업 보상과 같은 {@link RewardGrant} 모양을 쓴다 — 앱이 보상을 한 가지로만 파싱하면 된다.
     */
    public record Entry(Long id, String name, boolean secret, RewardGrant reward) {
    }

    /** 아무것도 새로 얻지 않았을 때. */
    public static CollectionOutcome none() {
        return new CollectionOutcome(List.of(), List.of());
    }
}
