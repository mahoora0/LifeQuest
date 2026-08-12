-- Seed regional location quests and location-template quests.
-- IDs 69-105 are reserved for this migration.

INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('부산시민공원 산책하기', '부산시민공원의 산책로를 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15, '부산시민공원', 35.1651000, 129.0576000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('광안리 바다 보기', '광안리해수욕장에서 파도 소리를 들으며 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32, '광안리해수욕장', 35.1531000, 129.1187000, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('감천 골목 오르기', '감천문화마을의 계단 골목을 정상까지 올라 보세요.', 'EPIC', 'DAILY', 'LOCATION', 47, '감천문화마을', 35.0975000, 129.0107000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('자갈치시장에서 한 끼 먹기', '자갈치시장에서 먹거리를 하나 골라 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40, '자갈치시장', 35.0966000, 129.0306000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('해운대에서 반나절 보내기', '해운대해수욕장에서 바다를 보며 여유를 즐겨 보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75, '해운대해수욕장', 35.1587000, 129.1604000, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('태종대 한 바퀴 완주하기', '태종대 순환로를 걸어 완주해 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200, '태종대', 35.0536000, 129.0873000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('수목원 산책하기', '대구수목원의 산책로를 따라 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15, '대구수목원', 35.8016000, 128.5556000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('김광석길 걸어 보기', '김광석 다시그리기길의 벽화를 따라 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32, '김광석 다시그리기길', 35.8654000, 128.6027000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('83타워에서 전시 내려다보기', '이월드 83타워 전망대에서 대구 시내를 내려다보세요.', 'EPIC', 'DAILY', 'LOCATION', 47, '이월드 83타워', 35.8534000, 128.5652000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('서문시장 구경하기', '서문시장을 돌아보며 먹거리를 골라 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40, '서문시장', 35.8695000, 128.5830000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('박물관에서 반나절 보내기', '국립대구박물관의 전시를 둘러보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75, '국립대구박물관', 35.8398000, 128.6449000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('앞산 정상 오르기', '앞산공원 등산로를 따라 전망대까지 올라 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200, '앞산공원', 35.8280000, 128.5750000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('센트럴파크 산책하기', '송도 센트럴파크의 수로를 따라 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15, '송도 센트럴파크', 37.3925000, 126.6390000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('월미도 바닷바람 쐬기', '월미도 문화의 거리를 걸으며 바닷바람을 맞아 보세요.', 'RARE', 'DAILY', 'LOCATION', 32, '월미도', 37.4740000, 126.5975000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('차이나타운 골목 걷기', '인천 차이나타운의 골목을 따라 걸어 보세요.', 'EPIC', 'DAILY', 'LOCATION', 47, '인천 차이나타운', 37.4750000, 126.6175000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('소래포구에서 회 보기', '소래포구 어시장에서 제철 먹거리를 찾아보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40, '소래포구', 37.4010000, 126.7380000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('기념관에서 역사 읽어 보기', '인천상륙작전기념관의 전시를 둘러보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75, '인천상륙작전기념관', 37.4432000, 126.6483000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('인천대공원 완주하기', '인천대공원 둘레길을 걸어 완주해 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200, '인천대공원', 37.4470000, 126.7530000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('한밭수목원 걷기', '한밭수목원의 산책길을 따라 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15, '한밭수목원', 36.3690000, 127.3880000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('으능정이 거리 걷기', '으능정이 스카이로드 아래의 거리를 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32, '으능정이 스카이로드', 36.3280000, 127.4270000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('과학관 전시 둘러보기', '국립중앙과학관에서 전시관 하나를 골라 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47, '국립중앙과학관', 36.3760000, 127.3760000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('장태산에서 하루 보내기', '장태산자연휴양림의 숲길을 돌아보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40, '장태산자연휴양림', 36.2740000, 127.3800000, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('대청호 물길 걷기', '대청호 오백리길 한 구간을 걸어 보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75, '대청호 오백리길', 36.4780000, 127.4830000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('계족산 황톳길 완주하기', '계족산 황톳길을 맨발로 걸어 완주해 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200, '계족산 황톳길', 36.3830000, 127.4530000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('기념공원 산책하기', '5·18기념공원의 산책로를 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15, '5·18기념공원', 35.1520000, 126.8770000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('양림동 골목 걷기', '양림동 근대역사문화마을의 골목을 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32, '양림동 근대역사문화마을', 35.1370000, 126.9140000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('문화전당 둘러보기', '국립아시아문화전당의 전시나 공연을 하나 즐겨 보세요.', 'EPIC', 'DAILY', 'LOCATION', 47, '국립아시아문화전당', 35.1468000, 126.9195000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('시립미술관 관람하기', '광주시립미술관에서 전시를 감상해 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40, '광주시립미술관', 35.1830000, 126.8880000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('호수생태원 걷기', '광주호 호수생태원의 산책로를 걸어 보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75, '광주호 호수생태원', 35.2170000, 126.9840000, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('무등산 증심사 오르기', '무등산 증심사 코스를 따라 올라 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200, '무등산 증심사', 35.1290000, 126.9600000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('서울로 걸어서 건너기', '서울로7017을 걸어서 지나가 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15, '서울로7017', 37.5560000, 126.9723000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('성곽길 올라 전시 내려다보기', '낙산공원 성곽길을 따라 올라 서울 야경을 내려다보세요.', 'EPIC', 'DAILY', 'LOCATION', 47, '낙산공원', 37.5805000, 127.0075000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at, is_location_template
) VALUES
    ('동네 한 바퀴 걷기', '지도에 표시된 지점까지 걸어가 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15, '현재 위치 주변', 37.4845000, 130.9057000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6), TRUE),
    ('가 보지 않은 길로 걷기', '지도에 표시된 지점까지 평소 다니지 않던 길로 가 보세요.', 'RARE', 'DAILY', 'LOCATION', 32, '현재 위치 주변', 37.4845000, 130.9057000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6), TRUE),
    ('해 지기 전에 돌아오기', '해가 지기 전에 지도에 표시된 지점까지 다녀오세요.', 'EPIC', 'DAILY', 'LOCATION', 47, '현재 위치 주변', 37.4845000, 130.9057000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6), TRUE),
    ('주변 카페 새로 찾기', '지도에 표시된 지점 근처에서 가 본 적 없는 가게에 들러 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40, '현재 위치 주변', 37.4845000, 130.9057000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6), TRUE),
    ('반나절 동네 탐방하기', '지도에 표시된 지점을 시작으로 동네를 반나절 돌아보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75, '현재 위치 주변', 37.4845000, 130.9057000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6), TRUE);
