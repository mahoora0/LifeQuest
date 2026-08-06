CREATE TABLE notifications (
    id         BIGINT       NOT NULL AUTO_INCREMENT,
    user_id    BIGINT       NOT NULL,
    kind       VARCHAR(30)  NOT NULL,
    title      VARCHAR(255) NOT NULL,
    route      VARCHAR(255),
    read_at    DATETIME(6),
    created_at DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE INDEX idx_notifications_user_created
    ON notifications (user_id, created_at DESC, id DESC);
CREATE INDEX idx_notifications_user_read
    ON notifications (user_id, read_at);
