CREATE TABLE quest_groups (
    id BIGINT NOT NULL AUTO_INCREMENT,
    owner_user_id BIGINT NOT NULL,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500) NOT NULL,
    visibility VARCHAR(20) NOT NULL,
    max_members INT NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_quest_groups_owner FOREIGN KEY (owner_user_id) REFERENCES users (id),
    CONSTRAINT ck_quest_groups_max_members CHECK (max_members BETWEEN 2 AND 100)
);
CREATE INDEX idx_quest_groups_public_search ON quest_groups (visibility, status, id);
CREATE INDEX idx_quest_groups_owner ON quest_groups (owner_user_id, status);

CREATE TABLE group_members (
    id BIGINT NOT NULL AUTO_INCREMENT,
    group_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    role VARCHAR(20) NOT NULL,
    status VARCHAR(30) NOT NULL,
    invited_by_user_id BIGINT NULL,
    expires_at DATETIME(6) NULL,
    responded_at DATETIME(6) NULL,
    joined_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_group_members_group_user UNIQUE (group_id, user_id),
    CONSTRAINT fk_group_members_group FOREIGN KEY (group_id) REFERENCES quest_groups (id),
    CONSTRAINT fk_group_members_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_group_members_inviter FOREIGN KEY (invited_by_user_id) REFERENCES users (id)
);
CREATE INDEX idx_group_members_user_status ON group_members (user_id, status, id);
CREATE INDEX idx_group_members_group_status ON group_members (group_id, status, id);
