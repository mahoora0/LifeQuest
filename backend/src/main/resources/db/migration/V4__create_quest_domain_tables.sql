-- Quest domain tables (담당: 팀원 2 — 퀘스트 배정·완료·GPS 인증).
-- 스키마 근거: docs/03-database-design.md §2-2.
--
-- 크로스도메인 FK 보류: lifedex_item_id → LIFEDEX_ITEMS(팀원3)는 해당 테이블이 아직 없어
-- FK 제약 없이 BIGINT 컬럼으로만 둔다. user_id의 참조 대상 users는 V2__auth_and_users에
-- 이미 있으므로 FK 추가가 가능하다 — 후속 마이그레이션에서 결정한다.
-- 도메인 내부 FK와 UNIQUE 제약은 지금 확정한다.
-- ENUM은 H2(MySQL 모드)/MySQL 양쪽 호환을 위해 VARCHAR로 저장한다(JPA @Enumerated STRING).

CREATE TABLE quests (
    id              BIGINT       NOT NULL AUTO_INCREMENT,
    title           VARCHAR(100) NOT NULL,
    description     VARCHAR(500),
    grade           VARCHAR(20)  NOT NULL,
    completion_type VARCHAR(20)  NOT NULL,
    exp_reward      INT          NOT NULL,
    place_name      VARCHAR(100),
    latitude        DECIMAL(10,7),
    longitude       DECIMAL(10,7),
    radius_m        INT,
    lifedex_item_id BIGINT,
    created_by      VARCHAR(20)  NOT NULL,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      DATETIME(6)  NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX idx_quests_location ON quests (latitude, longitude);

CREATE TABLE user_daily_quests (
    id            BIGINT      NOT NULL AUTO_INCREMENT,
    user_id       BIGINT      NOT NULL,
    quest_id      BIGINT      NOT NULL,
    assigned_date DATE        NOT NULL,
    status        VARCHAR(20) NOT NULL,
    expires_at    DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_user_daily_quests UNIQUE (user_id, quest_id, assigned_date),
    CONSTRAINT fk_udq_quest FOREIGN KEY (quest_id) REFERENCES quests (id)
);
CREATE INDEX idx_udq_user_date ON user_daily_quests (user_id, assigned_date);

CREATE TABLE quest_completions (
    id                  BIGINT      NOT NULL AUTO_INCREMENT,
    user_daily_quest_id BIGINT      NOT NULL,
    user_id             BIGINT      NOT NULL,
    quest_id            BIGINT      NOT NULL,
    verified_latitude   DECIMAL(10,7),
    verified_longitude  DECIMAL(10,7),
    distance_m          DECIMAL(8,2),
    accuracy_m          DECIMAL(8,2),
    completed_at        DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    -- 완료 멱등성의 근거: 하나의 배정 건은 완료 기록을 하나만 가진다.
    CONSTRAINT uk_quest_completions_udq UNIQUE (user_daily_quest_id),
    CONSTRAINT fk_qc_udq FOREIGN KEY (user_daily_quest_id) REFERENCES user_daily_quests (id),
    CONSTRAINT fk_qc_quest FOREIGN KEY (quest_id) REFERENCES quests (id)
);
CREATE INDEX idx_qc_user ON quest_completions (user_id);
