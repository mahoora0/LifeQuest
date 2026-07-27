CREATE TABLE avatar_characters (
    id BIGINT NOT NULL AUTO_INCREMENT,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(50) NOT NULL,
    asset_key VARCHAR(100) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id),
    CONSTRAINT uk_avatar_characters_code UNIQUE (code)
);

CREATE TABLE titles (
    id BIGINT NOT NULL AUTO_INCREMENT,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(50) NOT NULL,
    description VARCHAR(255) NULL,
    acquire_type VARCHAR(20) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_titles_code UNIQUE (code)
);

CREATE TABLE profile_items (
    id BIGINT NOT NULL AUTO_INCREMENT,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    item_type VARCHAR(20) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_profile_items_code UNIQUE (code)
);

CREATE TABLE user_titles (
    id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    title_id BIGINT NOT NULL,
    source_type VARCHAR(30) NOT NULL,
    source_id BIGINT NOT NULL,
    acquired_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_user_titles_user_title UNIQUE (user_id, title_id),
    CONSTRAINT fk_user_titles_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_user_titles_title FOREIGN KEY (title_id) REFERENCES titles (id)
);

CREATE TABLE user_profile_items (
    id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    profile_item_id BIGINT NOT NULL,
    source_type VARCHAR(30) NOT NULL,
    source_id BIGINT NOT NULL,
    acquired_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_user_profile_items_user_item UNIQUE (user_id, profile_item_id),
    CONSTRAINT fk_user_profile_items_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_user_profile_items_item FOREIGN KEY (profile_item_id) REFERENCES profile_items (id)
);

CREATE TABLE level_rewards (
    id BIGINT NOT NULL AUTO_INCREMENT,
    level INT NOT NULL,
    reward_type VARCHAR(20) NOT NULL,
    reward_ref_id BIGINT NOT NULL,
    description VARCHAR(255) NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_level_rewards UNIQUE (level, reward_type, reward_ref_id)
);

CREATE TABLE exp_logs (
    id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    source_type VARCHAR(30) NOT NULL,
    source_id BIGINT NOT NULL,
    exp_amount INT NOT NULL,
    created_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_exp_logs_source UNIQUE (user_id, source_type, source_id),
    CONSTRAINT fk_exp_logs_user FOREIGN KEY (user_id) REFERENCES users (id)
);

ALTER TABLE users ADD COLUMN selected_character_id BIGINT NULL;
ALTER TABLE users ADD COLUMN representative_title_id BIGINT NULL;
ALTER TABLE users ADD COLUMN representative_badge_id BIGINT NULL;
ALTER TABLE users ADD CONSTRAINT fk_users_character
    FOREIGN KEY (selected_character_id) REFERENCES avatar_characters (id);
ALTER TABLE users ADD CONSTRAINT fk_users_representative_title
    FOREIGN KEY (representative_title_id) REFERENCES titles (id);
ALTER TABLE users ADD CONSTRAINT fk_users_representative_badge
    FOREIGN KEY (representative_badge_id) REFERENCES profile_items (id);

CREATE INDEX idx_exp_logs_user ON exp_logs (user_id);
CREATE INDEX idx_user_titles_user ON user_titles (user_id);
CREATE INDEX idx_user_profile_items_user ON user_profile_items (user_id);

INSERT INTO avatar_characters (id, code, name, asset_key, is_active) VALUES
    (1, 'ROOKIE', '루키', 'rookie.png', TRUE),
    (2, 'MOGAK', '모각', 'mogak.png', TRUE),
    (3, 'MONGLE', '몽글', 'mongle.png', TRUE),
    (4, 'TOTO', '토토', 'toto.png', TRUE);

INSERT INTO titles (id, code, name, description, acquire_type) VALUES
    (1, 'NEW_ADVENTURER', '새내기 모험가', 'LifeQuest의 첫걸음을 시작했어요.', 'LEVEL'),
    (2, 'NEIGHBORHOOD_EXPLORER', '동네 탐험가', '레벨 2를 달성했어요.', 'LEVEL'),
    (3, 'LIFE_MASTER', '라이프 마스터', '레벨 5를 달성했어요.', 'LEVEL');

INSERT INTO profile_items (id, code, name, item_type) VALUES
    (1, 'SPROUT_BADGE', '새싹 배지', 'BADGE'),
    (2, 'COMPASS_BADGE', '나침반 배지', 'BADGE'),
    (3, 'GOLD_BADGE', '황금 모험가 배지', 'BADGE');

INSERT INTO level_rewards (level, reward_type, reward_ref_id, description) VALUES
    (1, 'TITLE', 1, '가입 기념 기본 칭호'),
    (1, 'PROFILE_ITEM', 1, '가입 기념 기본 배지'),
    (2, 'TITLE', 2, '레벨 2 달성 칭호'),
    (3, 'PROFILE_ITEM', 2, '레벨 3 달성 배지'),
    (5, 'TITLE', 3, '레벨 5 달성 칭호'),
    (5, 'PROFILE_ITEM', 3, '레벨 5 달성 배지');

UPDATE users SET selected_character_id = 1 WHERE selected_character_id IS NULL;

INSERT INTO user_titles (user_id, title_id, source_type, source_id, acquired_at)
SELECT id, 1, 'LEVEL', 1, CURRENT_TIMESTAMP(6)
FROM users;

INSERT INTO user_profile_items (
    user_id, profile_item_id, source_type, source_id, acquired_at
)
SELECT id, 1, 'LEVEL', 1, CURRENT_TIMESTAMP(6)
FROM users;

UPDATE users SET representative_title_id = 1
WHERE representative_title_id IS NULL;
UPDATE users SET representative_badge_id = 1
WHERE representative_badge_id IS NULL;
