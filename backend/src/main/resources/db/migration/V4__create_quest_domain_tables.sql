-- Quest domain tables (담당: 팀원 2 — 퀘스트 배정·완료·GPS 인증).
-- 스키마 근거: docs/03-database-design.md §2-2.
--
-- 크로스도메인 FK 보류: lifedex_item_id → LIFEDEX_ITEMS(팀원 3)는 해당 테이블이 아직 없다.
-- user_id → USERS(팀원 1)는 테이블이 V2__auth_and_users에 있지만, 타 담당 테이블에 제약을
-- 발생시키므로 퀘스트 도메인 담당(팀원 2)이 단독으로 결정할 사안이 아니다. 둘 다 FK 없이 BIGINT
-- 컬럼으로만 두고, user_id 값 정합성은 QuestCompletion 생성자의 배정 건 파생으로 보장한다.
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
    PRIMARY KEY (id),
    -- GPS 판정 가능성의 DB 레벨 근거: LOCATION 완료 유형은 좌표와 양수 반경이 반드시 있어야 한다.
    -- 비어 있으면 배정된 사용자가 완료도 해제도 못 하는 행이 배정 풀에 들어간다.
    CONSTRAINT ck_quests_location_verifiable CHECK (
        completion_type <> 'LOCATION'
        OR (latitude IS NOT NULL AND longitude IS NOT NULL
            AND radius_m IS NOT NULL AND radius_m > 0)
    )
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
