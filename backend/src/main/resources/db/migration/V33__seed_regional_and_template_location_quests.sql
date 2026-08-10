-- 지역 분산 LOCATION 시드 30건 + 장소 미지정 템플릿 5건 (담당: 팀원 2 — 퀘스트 배정·완료·GPS 인증).
-- 등급·EXP 기준: docs/05-business-rules.md §2 / 인증 반경: 같은 문서 §3-1 / 슬롯: 같은 문서 §1-A.
--
-- V22 머리말이 미뤄 둔 LOCATION 결손을 여기서 닫는다. 결손은 둘이었고 원인이 서로 달랐다.
--
--   지역 — 시드가 전부 서울이라(V6) 서울 밖 사용자는 슬롯 A를 완료할 수 없었다.
--   등급 — 일간 LOCATION이 RARE 4건뿐이라 슬롯 A의 등급이 사실상 고정이었다.
--
-- 두 결손이 같은 마이그레이션에 오는 이유는 배정이 이제 사용자 주변으로 후보를 좁히기 때문이다
-- (V32). 좁히고 나면 등급 분포를 정하는 것은 카탈로그 전체가 아니라 그 도시의 구성이므로,
-- 도시마다 등급이 갖춰져 있지 않으면 좁히는 순간 그 사용자의 슬롯 A가 한 등급에 묶인다.
-- 지역만 늘리고 등급을 두면 결손을 옮길 뿐이다.
--
-- 그래서 도시마다 같은 구성을 넣는다 — 일간 NORMAL·RARE·EPIC 각 1건, 주간 RARE·EPIC·LEGENDARY 각 1건.
-- 일간에 LEGENDARY를, 주간에 NORMAL을 두지 않는 것은 기존 트랙 대역과 맞춘 것이다(V22 머리말).
--
-- 대상 도시는 서울을 뺀 5대 광역시다(부산·대구·인천·대전·광주). 판정 반경 50km 안에 들어오는
-- 인접 도시가 함께 덮인다 — 수원·성남은 서울권, 김해·양산은 부산권으로 잡힌다.
--
-- 좌표는 V6과 같이 시연·개발용 근사값이다. 대표 지점을 소수점 넷째 자리까지 적었고 미터 단위
-- 정밀도는 보장하지 않는다. 인증 반경이 오차를 흡수하도록 잡았으나 운영 배포 전 실측 검증이 필요하다.
-- 반경은 §3-1 구간(카페·음식점 50m / 공원·관광지 100m / 산 등 넓은 장소 200~500m)에 맞췄고,
-- 해수욕장·호수·둘레길처럼 지점이 아니라 구역인 곳은 한 단계 넓게 잡았다.
--
-- id는 69번부터다. 1~68을 지우지 않는 계약(V6 머리말)은 여기에도 적용한다 — 내릴 때는 행을
-- 지우지 말고 is_active=false로 바꾼다.
--
-- lifedex_item_id는 전부 NULL이다. 도감 연계의 자연스러운 후보가 LOCATION이므로(V6 머리말)
-- LIFEDEX_ITEMS와 이을 대상이 늘었지만, 연결은 팀원 3의 항목 정의를 받은 뒤 UPDATE로 한다.

-- 부산 —— 일간 3 / 주간 3
INSERT INTO quests (
    id, title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    (69, '시민공원 산책하기', '부산시민공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '부산시민공원', 35.1651000, 129.0576000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (70, '광안리 바다 보기', '광안리해수욕장에서 파도 소리를 들으며 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '광안리해수욕장', 35.1531000, 129.1187000, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (71, '감천 골목 오르기', '감천문화마을의 계단 골목을 끝까지 올라 보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '감천문화마을', 35.0975000, 129.0107000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (72, '자갈치시장에서 장 보기', '자갈치시장에 들러 먹거리나 찬거리를 사 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '자갈치시장', 35.0966000, 129.0306000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (73, '해운대에서 반나절 보내기', '해운대해수욕장에서 바다를 보며 반나절을 보내세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '해운대해수욕장', 35.1587000, 129.1604000, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (74, '태종대 한 바퀴 완주하기', '태종대 순환로를 걸어서 완주해 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '태종대', 35.0536000, 129.0873000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 대구 —— 일간 3 / 주간 3
INSERT INTO quests (
    id, title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    (75, '수목원 한 바퀴 걷기', '대구수목원의 산책로를 따라 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '대구수목원', 35.8016000, 128.5556000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (76, '김광석길 걸어 보기', '김광석다시그리기길의 벽화를 따라 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '김광석다시그리기길', 35.8654000, 128.6027000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (77, '83타워에서 도시 내려다보기', '이월드 83타워 전망대에서 대구 시내를 내려다보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '이월드 83타워', 35.8534000, 128.5652000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (78, '서문시장 구경하기', '서문시장을 돌아보며 먹거리를 골라 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '서문시장', 35.8695000, 128.5830000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (79, '박물관에서 반나절 보내기', '국립대구박물관을 천천히 둘러보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '국립대구박물관', 35.8398000, 128.6449000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (80, '앞산 정상 오르기', '앞산공원 등산로를 따라 전망대까지 올라 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '앞산공원', 35.8280000, 128.5750000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 인천 —— 일간 3 / 주간 3
INSERT INTO quests (
    id, title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    (81, '센트럴파크 산책하기', '송도센트럴파크의 수로를 따라 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '송도센트럴파크', 37.3925000, 126.6390000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (82, '월미도 바닷바람 쐬기', '월미도 문화의거리를 걸으며 바닷바람을 맞아 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '월미도', 37.4740000, 126.5975000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (83, '차이나타운 골목 걷기', '인천차이나타운의 골목을 따라 걸어 보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '인천차이나타운', 37.4750000, 126.6175000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (84, '소래포구에서 장 보기', '소래포구 어시장에 들러 제철 먹거리를 사 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '소래포구', 37.4010000, 126.7380000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (85, '기념관에서 역사 훑어보기', '인천상륙작전기념관을 둘러보며 전시를 읽어 보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '인천상륙작전기념관', 37.4432000, 126.6483000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (86, '인천대공원 완주하기', '인천대공원 둘레길을 걸어서 완주해 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '인천대공원', 37.4470000, 126.7530000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 대전 —— 일간 3 / 주간 3
INSERT INTO quests (
    id, title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    (87, '한밭수목원 걷기', '한밭수목원의 숲길을 따라 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '한밭수목원', 36.3690000, 127.3880000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (88, '으능정이 거리 걷기', '으능정이 스카이로드 아래를 지나 거리를 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '으능정이 스카이로드', 36.3280000, 127.4270000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (89, '과학관 전시 둘러보기', '국립중앙과학관에서 전시관을 하나 골라 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '국립중앙과학관', 36.3760000, 127.3760000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (90, '오월드에서 하루 보내기', '대전 오월드에 들러 한 바퀴 돌아보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '대전 오월드', 36.2740000, 127.3800000, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (91, '대청호 물가 걷기', '대청호 오백리길 한 구간을 걸어 보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '대청호 오백리길', 36.4780000, 127.4830000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (92, '계족산 황톳길 완주하기', '계족산 황톳길을 맨발로 걸어 완주해 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '계족산 황톳길', 36.3830000, 127.4530000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 광주 —— 일간 3 / 주간 3
INSERT INTO quests (
    id, title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    (93, '기념공원 산책하기', '5·18기념공원을 천천히 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '5·18기념공원', 35.1520000, 126.8770000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (94, '양림동 골목 걷기', '양림동 근대역사문화마을의 골목을 따라 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '양림동 근대역사문화마을', 35.1370000, 126.9140000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (95, '문화전당 둘러보기', '국립아시아문화전당에서 전시나 공연을 하나 보고 오세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '국립아시아문화전당', 35.1468000, 126.9195000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (96, '시립미술관 관람하기', '광주시립미술관에서 전시를 한 편 보고 오세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '광주시립미술관', 35.1830000, 126.8880000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (97, '호수생태원 걷기', '광주호 호수생태원의 산책로를 걸어 보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '광주호 호수생태원', 35.2170000, 126.9840000, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (98, '무등산 증심사 오르기', '무등산 증심사 계곡을 따라 올라 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '무등산 증심사', 35.1290000, 126.9600000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 서울 —— 일간 등급 보강 2건.
--
-- 서울만 다른 도시와 구성이 다르다. 이미 일간 LOCATION 4건(21~24)이 있는데 전부 RARE라
-- NORMAL·EPIC이 비어 있었다 — V22 머리말이 "일간 LOCATION이 RARE 4건뿐"이라고 적어 둔 그 결손이다.
-- 일간 판정 반경이 15km라 인천 시드가 서울 사용자에게 닿지 않으므로, 서울에도 직접 넣어야 메워진다.
INSERT INTO quests (
    id, title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    -- 반경 500m는 §3-1의 "넓은 장소" 상한이며, 여기서는 이 구조물이 약 1km에 걸친 선형 공간이기
    -- 때문이다. 200m로 두면 중앙 좌표에서 먼 양 끝에 선 사용자가 인증에 실패한다 — 도착은 했는데
    -- 완료가 안 되는 상태이고, 어느 끝에서 출발했는지에 따라 갈려 재현도 어렵다.
    (99,  '서울로 걸어서 건너기', '서울로7017을 걸어서 지나가 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '서울로7017', 37.5560000, 126.9723000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (100, '성곽길 올라 도시 내려다보기', '낙산공원 성곽길을 따라 올라 서울 야경을 내려다보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '낙산공원', 37.5805000, 127.0075000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 장소 미지정 템플릿 5건 —— 시드된 도시가 주변에 하나도 없는 사용자를 위한 마지막 후보다.
--
-- 좌표는 배정 시점에 사용자 주변으로 만들어져 user_daily_quests의 override 컬럼에 붙는다(V32).
-- 여기 적힌 좌표는 그 override가 항상 덮으므로 사용자에게 보이지 않는다 — 그런데도 값을 넣는
-- 이유는 ck_quests_location_verifiable이 좌표 없는 LOCATION을 거부하기 때문이고, 그 제약은
-- 유지되어야 한다. 좌표 없는 LOCATION이 일반 경로로 들어오면 배정받은 사용자가 완료도 해제도
-- 못 하는 상태에 빠진다(Quest 엔티티 주석).
--
-- 값은 울릉도로 둔다. 배정 코드가 템플릿을 후보에 넣는 경로는 사용자 좌표가 있을 때 하나뿐이라
-- override 없이 배정될 수 없지만, 만에 하나 그 경로가 깨져 이 좌표가 그대로 쓰이면 시드된 여섯
-- 도시 어디에서도 250km 밖이라 누구에게든 눈에 띈다.
--
-- 국토 중앙(36.5, 127.85)을 먼저 골랐다가 물렀다. 대전에서 44km라 주간 판정 반경(50km) 안에
-- 들어와, override가 빠져도 대전 사용자에게는 정상으로 보였다 — "아무 도시도 아닌 곳"과
-- "어느 도시에서도 먼 곳"은 다르고, 필요한 것은 후자다. 시드 계약 테스트가 이것을 잰다.
--
-- 등급을 일간 셋·주간 둘로 갈라 두는 것도 도시 시드와 같은 이유다. 템플릿만 후보인 사용자에게
-- 템플릿이 한 건뿐이면 그 사용자의 슬롯 A는 매번 같은 퀘스트가 된다.
--
-- 반경 500m는 §3-1의 상한이며 여기서는 "지점"이 아니라 "구역"의 뜻이다. 오프셋으로 만든 지점이
-- 건물 안이나 도로 한가운데일 수 있어, 그 주변 어디서나 인증되도록 넓게 잡는다.
INSERT INTO quests (
    id, title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at, is_location_template
) VALUES
    (101, '동네 한 바퀴 걷기', '지도에 표시된 지점까지 걸어가 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '현재 위치 주변', 37.4845000, 130.9057000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6), TRUE),
    (102, '가 보지 않은 길로 걷기', '지도에 표시된 지점까지 평소 다니지 않던 길로 가 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '현재 위치 주변', 37.4845000, 130.9057000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6), TRUE),
    (103, '해 지기 전에 다녀오기', '해가 지기 전에 지도에 표시된 지점까지 다녀오세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '현재 위치 주변', 37.4845000, 130.9057000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6), TRUE),
    (104, '주변 카페 새로 뚫기', '지도에 표시된 지점 근처에서 가 본 적 없는 가게에 들러 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '현재 위치 주변', 37.4845000, 130.9057000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6), TRUE),
    (105, '반나절 동네 탐방하기', '지도에 표시된 지점을 시작으로 동네를 반나절 돌아보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '현재 위치 주변', 37.4845000, 130.9057000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6), TRUE);
