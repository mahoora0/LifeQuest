CREATE TABLE achievements (
    id                            BIGINT       NOT NULL AUTO_INCREMENT,
    code                          VARCHAR(50)  NOT NULL,
    name                          VARCHAR(100) NOT NULL,
    description                   VARCHAR(255) NOT NULL,
    condition_type                VARCHAR(30)  NOT NULL,
    condition_key                 VARCHAR(30),
    target_quest_id               BIGINT,
    target_lifedex_category_id    BIGINT,
    is_secret                     BOOLEAN      NOT NULL DEFAULT FALSE,
    display_order                 INT          NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_achievements_code UNIQUE (code),
    CONSTRAINT fk_achievements_quest
        FOREIGN KEY (target_quest_id) REFERENCES quests (id),
    CONSTRAINT fk_achievements_lifedex_category
        FOREIGN KEY (target_lifedex_category_id) REFERENCES lifedex_categories (id)
);

CREATE TABLE achievement_steps (
    id                BIGINT       NOT NULL AUTO_INCREMENT,
    achievement_id    BIGINT       NOT NULL,
    step_no           INT          NOT NULL,
    name              VARCHAR(100) NOT NULL,
    required_count    INT          NOT NULL,
    reward_title_id   BIGINT,
    PRIMARY KEY (id),
    CONSTRAINT uk_achievement_steps UNIQUE (achievement_id, step_no),
    CONSTRAINT fk_achievement_steps_achievement
        FOREIGN KEY (achievement_id) REFERENCES achievements (id),
    CONSTRAINT fk_achievement_steps_reward_title
        FOREIGN KEY (reward_title_id) REFERENCES titles (id),
    CONSTRAINT ck_achievement_steps_positive
        CHECK (step_no > 0 AND required_count > 0)
);

CREATE TABLE user_achievements (
    id                BIGINT      NOT NULL AUTO_INCREMENT,
    user_id           BIGINT      NOT NULL,
    achievement_id    BIGINT      NOT NULL,
    current_value     INT         NOT NULL DEFAULT 0,
    current_step      INT         NOT NULL DEFAULT 0,
    achieved_at       DATETIME(6),
    updated_at        DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_user_achievements UNIQUE (user_id, achievement_id),
    CONSTRAINT fk_user_achievements_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_user_achievements_achievement
        FOREIGN KEY (achievement_id) REFERENCES achievements (id)
);

CREATE INDEX idx_achievement_steps_achievement
    ON achievement_steps (achievement_id, step_no);
CREATE INDEX idx_user_achievements_user
    ON user_achievements (user_id);

INSERT INTO titles (code, name, description, acquire_type) VALUES
    ('ACHIEVEMENT_QUEST_MASTER', '삶의 퀴스트 마스터', '퀴스트 100회 완료 업적 보상입니다.', 'ACHIEVEMENT'),
    ('ACHIEVEMENT_SEOUL_EXPLORER', '서울 발걸음 수집가', '위치 인증 퀴스트 15회 완료 업적 보상입니다.', 'ACHIEVEMENT'),
    ('ACHIEVEMENT_DAILY_KEEPER', '일상의 수호자', '일간 퀴스트 100회 완료 업적 보상입니다.', 'ACHIEVEMENT'),
    ('ACHIEVEMENT_LEGEND', '전설을 쓰는 자', '전설 등급 퀴스트 업적 보상입니다.', 'ACHIEVEMENT');

INSERT INTO achievements
    (id, code, name, description, condition_type, condition_key,
     target_quest_id, target_lifedex_category_id, is_secret, display_order)
VALUES
    (1, 'QUEST_TOTAL', '모험의 발자국', '퀴스트를 완료해요.', 'CUMULATIVE_COUNT', NULL, NULL, NULL, FALSE, 1),
    (2, 'QUEST_LOCATION', '도시 탐험가', '위치 인증 퀴스트를 완료해요.', 'COMPLETION_TYPE', 'LOCATION', NULL, NULL, FALSE, 2),
    (3, 'QUEST_SELF_REPORT', '일상의 실천가', '직접 완료 퀴스트를 실천해요.', 'COMPLETION_TYPE', 'SELF_REPORT', NULL, NULL, FALSE, 3),
    (4, 'QUEST_DAILY', '매일의 힘', '일간 퀴스트를 꾸준히 완료해요.', 'CADENCE', 'DAILY', NULL, NULL, FALSE, 4),
    (5, 'QUEST_WEEKLY', '큰 도전 수집가', '주간 퀴스트를 완료해요.', 'CADENCE', 'WEEKLY', NULL, NULL, FALSE, 5),
    (6, 'QUEST_EPIC', '영웅의 길', '에픽 등급 퀴스트를 완료해요.', 'GRADE', 'EPIC', NULL, NULL, FALSE, 6),
    (7, 'QUEST_LEGENDARY', '전설의 시작', '전설 등급 퀴스트에 도전해요.', 'GRADE', 'LEGENDARY', NULL, NULL, TRUE, 7),
    (8, 'LIFEDEX_TOTAL', '기억 수집가', '퀴스트를 통해 도감 항목을 수집해요.', 'LIFEDEX_COUNT', NULL, NULL, NULL, FALSE, 8),
    (9, 'QUEST_WATER', '물 한 잔의 습관', '물 8잔 마시기 퀴스트를 반복해요.', 'SPECIFIC_QUEST', NULL, 1, NULL, FALSE, 9),
    (10, 'QUEST_WALK', '걸음의 승리자', '6,000보 걷기 퀴스트를 반복해요.', 'SPECIFIC_QUEST', NULL, 5, NULL, FALSE, 10),
    (11, 'QUEST_READING', '페이지 탐험가', '책 읽기 퀴스트를 반복해요.', 'SPECIFIC_QUEST', NULL, 7, NULL, FALSE, 11);

INSERT INTO achievement_steps
    (achievement_id, step_no, name, required_count, reward_title_id)
VALUES
    (1, 1, '모험의 발자국 I', 1, NULL),
    (1, 2, '모험의 발자국 II', 10, NULL),
    (1, 3, '모험의 발자국 III', 30, NULL),
    (1, 4, '모험의 발자국 IV', 100, (SELECT id FROM titles WHERE code = 'ACHIEVEMENT_QUEST_MASTER')),
    (2, 1, '도시 탐험가 I', 1, NULL),
    (2, 2, '도시 탐험가 II', 5, NULL),
    (2, 3, '도시 탐험가 III', 15, (SELECT id FROM titles WHERE code = 'ACHIEVEMENT_SEOUL_EXPLORER')),
    (3, 1, '일상의 실천가 I', 5, NULL),
    (3, 2, '일상의 실천가 II', 20, NULL),
    (3, 3, '일상의 실천가 III', 50, NULL),
    (4, 1, '매일의 힘 I', 7, NULL),
    (4, 2, '매일의 힘 II', 30, NULL),
    (4, 3, '매일의 힘 III', 100, (SELECT id FROM titles WHERE code = 'ACHIEVEMENT_DAILY_KEEPER')),
    (5, 1, '큰 도전 수집가 I', 3, NULL),
    (5, 2, '큰 도전 수집가 II', 10, NULL),
    (5, 3, '큰 도전 수집가 III', 30, NULL),
    (6, 1, '영웅의 길 I', 1, NULL),
    (6, 2, '영웅의 길 II', 5, NULL),
    (6, 3, '영웅의 길 III', 15, NULL),
    (7, 1, '전설의 시작', 1, (SELECT id FROM titles WHERE code = 'ACHIEVEMENT_LEGEND')),
    (8, 1, '기억 수집가 I', 1, NULL),
    (8, 2, '기억 수집가 II', 5, NULL),
    (8, 3, '기억 수집가 III', 10, NULL),
    (8, 4, '기억 수집가 IV', 15, NULL),
    (9, 1, '물 한 잔의 습관 I', 3, NULL),
    (9, 2, '물 한 잔의 습관 II', 10, NULL),
    (9, 3, '물 한 잔의 습관 III', 30, NULL),
    (10, 1, '걸음의 승리자 I', 3, NULL),
    (10, 2, '걸음의 승리자 II', 10, NULL),
    (10, 3, '걸음의 승리자 III', 30, NULL),
    (11, 1, '페이지 탐험가 I', 3, NULL),
    (11, 2, '페이지 탐험가 II', 10, NULL),
    (11, 3, '페이지 탐험가 III', 30, NULL);
