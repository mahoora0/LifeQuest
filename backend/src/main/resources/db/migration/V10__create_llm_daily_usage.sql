CREATE TABLE quest_recommendation_daily_usage (
    id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    usage_date DATE NOT NULL,
    request_count INT NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_recommendation_usage_user_date UNIQUE (user_id, usage_date),
    CONSTRAINT fk_recommendation_usage_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT ck_recommendation_usage_count CHECK (request_count >= 0)
);
