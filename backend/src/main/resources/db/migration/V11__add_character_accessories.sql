ALTER TABLE users ADD COLUMN selected_accessory_id BIGINT NULL;

ALTER TABLE users ADD CONSTRAINT fk_users_selected_accessory
    FOREIGN KEY (selected_accessory_id) REFERENCES profile_items (id);

INSERT INTO profile_items (id, code, name, item_type) VALUES
    (4, 'APRON', '앞치마', 'OUTFIT'),
    (5, 'EXPLORER_HAT', '탐험가 모자', 'OUTFIT'),
    (6, 'HERO_CAPE', '영웅 망토', 'OUTFIT'),
    (7, 'HOOD', '후드', 'OUTFIT'),
    (8, 'LEAF_HAT', '나뭇잎 모자', 'OUTFIT'),
    (9, 'MAGNIFYING', '돋보기', 'OUTFIT'),
    (10, 'MAP_SCROLL', '지도 두루마리', 'OUTFIT'),
    (11, 'MOON_GLASSES', '달 안경', 'OUTFIT'),
    (12, 'PICNIC_BASKET', '피크닉 바구니', 'OUTFIT'),
    (13, 'RAIN_PONCHO', '우비', 'OUTFIT'),
    (14, 'RIBBON_BOW', '리본', 'OUTFIT'),
    (15, 'ROUND_GLASSES', '동그란 안경', 'OUTFIT'),
    (16, 'SHOULDER_STRAP_BAG', '크로스백', 'OUTFIT'),
    (17, 'TINY_BACKPACK', '미니 백팩', 'OUTFIT');

INSERT INTO level_rewards (level, reward_type, reward_ref_id, description) VALUES
    (2, 'PROFILE_ITEM', 4, '레벨 2 액세서리'),
    (3, 'PROFILE_ITEM', 5, '레벨 3 액세서리'),
    (4, 'PROFILE_ITEM', 6, '레벨 4 액세서리'),
    (5, 'PROFILE_ITEM', 7, '레벨 5 액세서리'),
    (6, 'PROFILE_ITEM', 8, '레벨 6 액세서리'),
    (7, 'PROFILE_ITEM', 9, '레벨 7 액세서리'),
    (8, 'PROFILE_ITEM', 10, '레벨 8 액세서리'),
    (9, 'PROFILE_ITEM', 11, '레벨 9 액세서리'),
    (10, 'PROFILE_ITEM', 12, '레벨 10 액세서리'),
    (11, 'PROFILE_ITEM', 13, '레벨 11 액세서리'),
    (12, 'PROFILE_ITEM', 14, '레벨 12 액세서리'),
    (13, 'PROFILE_ITEM', 15, '레벨 13 액세서리'),
    (14, 'PROFILE_ITEM', 16, '레벨 14 액세서리'),
    (15, 'PROFILE_ITEM', 17, '레벨 15 액세서리');

-- 이미 해당 레벨을 달성한 사용자에게도 마이그레이션 시 보상을 소급 지급한다.
INSERT INTO user_profile_items (
    user_id, profile_item_id, source_type, source_id, acquired_at
)
SELECT
    users.id,
    rewards.reward_ref_id,
    'LEVEL',
    rewards.level,
    CURRENT_TIMESTAMP(6)
FROM users
JOIN level_rewards rewards
    ON rewards.reward_type = 'PROFILE_ITEM'
    AND rewards.reward_ref_id BETWEEN 4 AND 17
    AND users.level >= rewards.level
WHERE NOT EXISTS (
    SELECT 1
    FROM user_profile_items owned
    WHERE owned.user_id = users.id
      AND owned.profile_item_id = rewards.reward_ref_id
);
