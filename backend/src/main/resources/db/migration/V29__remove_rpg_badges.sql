-- RPG 배지 기능 제거. 칭호와 액세서리 등 다른 프로필 아이템은 유지한다.
ALTER TABLE users DROP FOREIGN KEY fk_users_representative_badge;
ALTER TABLE users DROP COLUMN representative_badge_id;

DELETE FROM level_rewards
WHERE reward_type = 'PROFILE_ITEM'
  AND reward_ref_id IN (
      SELECT id FROM profile_items WHERE item_type = 'BADGE'
  );

DELETE FROM user_profile_items
WHERE profile_item_id IN (
    SELECT id FROM profile_items WHERE item_type = 'BADGE'
);

DELETE FROM profile_items WHERE item_type = 'BADGE';
