ALTER TABLE users ADD COLUMN friend_code VARCHAR(16);

CREATE UNIQUE INDEX uk_users_friend_code ON users (friend_code);
