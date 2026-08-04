-- Friend request and friendship tables (담당: 팀원 4 — 친구 관계 관리).
-- 스키마 근거: docs/03-database-design.md §2-4, 친구 규칙: docs/05-business-rules.md §9.
-- ENUM은 H2(MySQL 모드)/MySQL 양쪽 호환을 위해 VARCHAR로 저장한다.

-- 요청자·수신자 외래 키
CREATE TABLE friend_requests (
    id           BIGINT       NOT NULL AUTO_INCREMENT,
    sender_id    BIGINT       NOT NULL,
    receiver_id  BIGINT       NOT NULL,
    status       VARCHAR(20)  NOT NULL,
    created_at   DATETIME(6)  NOT NULL,
    responded_at DATETIME(6)  NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_friend_requests_not_self CHECK (sender_id <> receiver_id),
    CONSTRAINT ck_friend_requests_status CHECK (
        status IN ('PENDING', 'ACCEPTED', 'REJECTED')
    ),
    CONSTRAINT fk_friend_requests_sender
        FOREIGN KEY (sender_id) REFERENCES users (id),
    CONSTRAINT fk_friend_requests_receiver
        FOREIGN KEY (receiver_id) REFERENCES users (id)
);

CREATE INDEX idx_friend_requests_receiver_status
    ON friend_requests (receiver_id, status);
CREATE INDEX idx_friend_requests_sender_receiver_status
    ON friend_requests (sender_id, receiver_id, status);

-- 사용자·친구 외래 키
CREATE TABLE friendships (
    id         BIGINT      NOT NULL AUTO_INCREMENT,
    user_id    BIGINT      NOT NULL,
    friend_id  BIGINT      NOT NULL,
    created_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_friendships_user_friend UNIQUE (user_id, friend_id),
    CONSTRAINT ck_friendships_not_self CHECK (user_id <> friend_id),
    CONSTRAINT fk_friendships_user
        FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_friendships_friend
        FOREIGN KEY (friend_id) REFERENCES users (id)
);

CREATE INDEX idx_friendships_friend ON friendships (friend_id);
