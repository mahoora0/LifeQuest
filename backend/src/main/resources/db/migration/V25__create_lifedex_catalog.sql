CREATE TABLE lifedex_categories (
    id BIGINT NOT NULL,
    name VARCHAR(50) NOT NULL,
    display_order INT NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_lifedex_categories_name UNIQUE (name),
    CONSTRAINT uk_lifedex_categories_order UNIQUE (display_order)
);

CREATE TABLE lifedex_items (
    id BIGINT NOT NULL,
    category_id BIGINT NOT NULL,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500) NULL,
    display_order INT NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_lifedex_items_name UNIQUE (name),
    CONSTRAINT fk_lifedex_items_category
        FOREIGN KEY (category_id) REFERENCES lifedex_categories (id)
);

CREATE INDEX idx_lifedex_items_category_order
    ON lifedex_items (category_id, display_order);

CREATE TABLE user_lifedex (
    id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    lifedex_item_id BIGINT NOT NULL,
    collected_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_user_lifedex UNIQUE (user_id, lifedex_item_id),
    CONSTRAINT fk_user_lifedex_user
        FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_user_lifedex_item
        FOREIGN KEY (lifedex_item_id) REFERENCES lifedex_items (id)
);

CREATE INDEX idx_user_lifedex_user ON user_lifedex (user_id);

-- 도감은 실제 LOCATION 퀘스트 15개만 싣는다. 항목 id를 원본 퀘스트 id와
-- 맞춰 두면 운영 중 매핑을 확인할 때 두 카탈로그를 바로 대조할 수 있다.
INSERT INTO lifedex_categories (id, name, display_order) VALUES
    (1, '카페', 1),
    (2, '공원 · 산책로', 2),
    (3, '문화 · 전시', 3),
    (4, '시장 · 골목', 4),
    (5, '산 · 하천', 5),
    (6, '역사 · 명소', 6);

INSERT INTO lifedex_items (id, category_id, name, description, display_order) VALUES
    (25, 1, '성수동 카페거리', '새로운 카페를 찾아 한 잔의 여유를 즐긴 기록', 1),
    (23, 2, '반포한강공원', '한강의 노을을 바라본 기록', 1),
    (24, 2, '서울숲', '아침 공기를 마시며 산책한 기록', 2),
    (32, 2, '경의선숲길', '도심 속 숲길을 걸은 기록', 3),
    (41, 2, '올림픽공원', '넓은 공원 둘레를 완주한 기록', 4),
    (42, 2, '서울식물원', '온실과 호수원을 둘러본 기록', 5),
    (22, 3, '서울도서관', '도서관에서 책과 시간을 보낸 기록', 1),
    (26, 3, '서울시립미술관', '전시를 관람한 기록', 2),
    (27, 3, '국립중앙박물관', '박물관을 천천히 둘러본 기록', 3),
    (29, 4, '북촌한옥마을', '한옥 골목을 따라 걸은 기록', 1),
    (30, 4, '광장시장', '전통시장에서 장을 본 기록', 2),
    (21, 5, '청계천', '청계천 물길을 따라 걸은 기록', 1),
    (40, 5, '북한산 백운대', '백운대 정상에 오른 기록', 2),
    (28, 6, '경복궁', '고궁의 뜰을 산책한 기록', 1),
    (31, 6, '남산서울타워', '남산에서 도시를 내려다본 기록', 2);

UPDATE quests SET lifedex_item_id = id
WHERE id IN (21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 40, 41, 42);

ALTER TABLE quests
    ADD CONSTRAINT fk_quests_lifedex_item
        FOREIGN KEY (lifedex_item_id) REFERENCES lifedex_items (id);
