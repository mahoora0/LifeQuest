-- 인증 광장: 퀘스트 완료 기록에 붙는 사진 인증 게시물과 사용자 투표.
--
-- 게시물은 항상 완료 기록에서 파생된다. quest_completion_id의 UNIQUE 제약 하나가
-- 세 가지를 동시에 보장한다 — ① 완료 1건당 게시물 1개(도배 차단), ② 퀘스트명은
-- 사용자 입력이 아니라 완료 기록에서 따라오므로 임의 퀘스트 사칭이 불가능,
-- ③ 나중에 완료 API가 사진을 직접 받도록 바뀌어도 스키마 변경이 필요 없다.
--
-- 좌표는 저장하지 않는다. docs/05-business-rules.md §3-5가 인증 좌표를 다른 사용자에게
-- 노출하지 않도록 정하고 있고, 이 피드는 전체 공개다.
CREATE TABLE quest_proof_posts (
    id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    quest_completion_id BIGINT NOT NULL,
    quest_id BIGINT NOT NULL,
    content VARCHAR(500),
    status VARCHAR(20) NOT NULL,
    agree_count INT NOT NULL DEFAULT 0,
    unsure_count INT NOT NULL DEFAULT 0,
    reject_count INT NOT NULL DEFAULT 0,
    comment_count INT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_quest_proof_posts_completion UNIQUE (quest_completion_id),
    CONSTRAINT fk_quest_proof_posts_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_quest_proof_posts_completion FOREIGN KEY (quest_completion_id) REFERENCES quest_completions (id),
    CONSTRAINT fk_quest_proof_posts_quest FOREIGN KEY (quest_id) REFERENCES quests (id)
);

-- 피드는 status로 거르고 id 역순으로 커서 페이징한다.
CREATE INDEX idx_quest_proof_posts_status ON quest_proof_posts (status, id);
CREATE INDEX idx_quest_proof_posts_user ON quest_proof_posts (user_id, id);

CREATE TABLE quest_proof_photos (
    id BIGINT NOT NULL AUTO_INCREMENT,
    post_id BIGINT NOT NULL,
    image_url VARCHAR(500) NOT NULL,
    sort_order INT NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_quest_proof_photos_order UNIQUE (post_id, sort_order),
    CONSTRAINT fk_quest_proof_photos_post FOREIGN KEY (post_id) REFERENCES quest_proof_posts (id)
);

-- 중복 투표 차단을 애플리케이션 조회가 아니라 DB 제약에 둔다. 동시 요청에서도 안전하고,
-- 투표 변경(번복)을 허용하지 않는다는 규칙이 스키마에 그대로 드러난다.
CREATE TABLE quest_proof_votes (
    id BIGINT NOT NULL AUTO_INCREMENT,
    post_id BIGINT NOT NULL,
    voter_user_id BIGINT NOT NULL,
    choice VARCHAR(20) NOT NULL,
    created_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_quest_proof_votes_voter UNIQUE (post_id, voter_user_id),
    CONSTRAINT fk_quest_proof_votes_post FOREIGN KEY (post_id) REFERENCES quest_proof_posts (id),
    CONSTRAINT fk_quest_proof_votes_voter FOREIGN KEY (voter_user_id) REFERENCES users (id)
);

-- 홈 섹션이 "내가 아직 투표하지 않은 게시물"을 찾을 때 쓰는 역방향 조회.
CREATE INDEX idx_quest_proof_votes_voter ON quest_proof_votes (voter_user_id, post_id);

CREATE TABLE quest_proof_comments (
    id BIGINT NOT NULL AUTO_INCREMENT,
    post_id BIGINT NOT NULL,
    author_user_id BIGINT NOT NULL,
    content VARCHAR(500) NOT NULL,
    created_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_quest_proof_comments_post FOREIGN KEY (post_id) REFERENCES quest_proof_posts (id),
    CONSTRAINT fk_quest_proof_comments_author FOREIGN KEY (author_user_id) REFERENCES users (id)
);

CREATE INDEX idx_quest_proof_comments_post ON quest_proof_comments (post_id, id);
