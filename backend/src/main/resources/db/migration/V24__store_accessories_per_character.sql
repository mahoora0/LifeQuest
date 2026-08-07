CREATE TABLE user_character_accessories (
    id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    character_id BIGINT NOT NULL,
    profile_item_id BIGINT NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_user_character_accessory UNIQUE (user_id, character_id),
    CONSTRAINT fk_user_character_accessory_user
        FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_user_character_accessory_character
        FOREIGN KEY (character_id) REFERENCES avatar_characters (id),
    CONSTRAINT fk_user_character_accessory_item
        FOREIGN KEY (profile_item_id) REFERENCES profile_items (id)
);

INSERT INTO user_character_accessories (user_id, character_id, profile_item_id)
SELECT id, selected_character_id, selected_accessory_id
FROM users
WHERE selected_character_id IS NOT NULL
  AND selected_accessory_id IS NOT NULL;

CREATE INDEX idx_user_character_accessories_user
    ON user_character_accessories (user_id);
