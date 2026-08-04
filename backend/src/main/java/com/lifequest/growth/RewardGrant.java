package com.lifequest.growth;

/**
 * 지급된 보상 한 건.
 *
 * <p>퀘스트 완료 응답의 {@code growth.rewards[]} 계약을 그대로 담는다
 * ({@code docs/04-api-spec.md} §4). 이름만 돌려주면 클라이언트가 칭호와 프로필
 * 아이템을 구분하지 못하고, 어떤 보상을 받았는지 코드로 대조할 수도 없다.
 *
 * @param type {@link LevelReward.RewardType}의 이름 — {@code TITLE} 또는 {@code PROFILE_ITEM}
 * @param code 보상 원본의 고유 코드
 * @param name 화면에 표시할 이름
 */
public record RewardGrant(String type, String code, String name) {
}
