ALTER TABLE group_quests
    ADD COLUMN exp_reward INT NOT NULL DEFAULT 40;

ALTER TABLE group_quests
    ADD COLUMN completed_at DATETIME(6) NULL;

ALTER TABLE group_quests
    ADD CONSTRAINT ck_group_quests_exp_reward CHECK (exp_reward > 0);

CREATE TABLE group_quest_participants (
    id BIGINT NOT NULL AUTO_INCREMENT,
    group_quest_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL,
    applied_at DATETIME(6) NOT NULL,
    withdrawn_at DATETIME(6) NULL,
    rewarded_at DATETIME(6) NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_group_quest_participants_quest_user UNIQUE (group_quest_id, user_id),
    CONSTRAINT fk_group_quest_participants_quest
        FOREIGN KEY (group_quest_id) REFERENCES group_quests (id),
    CONSTRAINT fk_group_quest_participants_user
        FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE INDEX idx_group_quest_participants_user_status
    ON group_quest_participants (user_id, status, group_quest_id);
CREATE INDEX idx_group_quest_participants_quest_status
    ON group_quest_participants (group_quest_id, status, id);
