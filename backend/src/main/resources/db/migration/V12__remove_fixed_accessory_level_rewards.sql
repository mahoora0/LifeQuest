-- 액세서리 카탈로그와 착용 기능은 유지하되 지급 레벨은 관리자 설정으로 관리한다.
-- V11에서 임시로 넣었던 레벨 2~15 고정 매핑과 소급 지급만 되돌린다.
UPDATE users
SET selected_accessory_id = NULL
WHERE selected_accessory_id BETWEEN 4 AND 17;

DELETE FROM user_profile_items
WHERE profile_item_id BETWEEN 4 AND 17
  AND source_type = 'LEVEL'
  AND source_id = profile_item_id - 2;

DELETE FROM level_rewards
WHERE reward_type = 'PROFILE_ITEM'
  AND reward_ref_id BETWEEN 4 AND 17
  AND level = reward_ref_id - 2;
