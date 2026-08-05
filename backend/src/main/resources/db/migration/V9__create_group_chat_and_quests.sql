CREATE TABLE group_chat_messages (
    id BIGINT NOT NULL AUTO_INCREMENT,
    group_id BIGINT NOT NULL,
    sender_user_id BIGINT NOT NULL,
    content VARCHAR(1000) NOT NULL,
    created_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_group_chat_messages_group FOREIGN KEY (group_id) REFERENCES quest_groups (id),
    CONSTRAINT fk_group_chat_messages_sender FOREIGN KEY (sender_user_id) REFERENCES users (id)
);
CREATE INDEX idx_group_chat_messages_group_id ON group_chat_messages (group_id, id);

CREATE TABLE group_quests (
    id BIGINT NOT NULL AUTO_INCREMENT,
    group_id BIGINT NOT NULL,
    created_by_user_id BIGINT NOT NULL,
    title VARCHAR(100) NOT NULL,
    description VARCHAR(1000) NOT NULL,
    place_name VARCHAR(200) NOT NULL,
    scheduled_at DATETIME(6) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_group_quests_group FOREIGN KEY (group_id) REFERENCES quest_groups (id),
    CONSTRAINT fk_group_quests_creator FOREIGN KEY (created_by_user_id) REFERENCES users (id)
);
CREATE INDEX idx_group_quests_group_schedule ON group_quests (group_id, scheduled_at, id);
