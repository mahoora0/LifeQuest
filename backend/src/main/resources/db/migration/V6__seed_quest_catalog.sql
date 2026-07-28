-- 초기 퀘스트 카탈로그 42건 (담당: 팀원 2 — 퀘스트 배정·완료·GPS 인증).
-- 등급·EXP 근거: docs/05-business-rules.md §2 / 인증 반경 근거: 같은 문서 §3-1.
--
-- V4가 quests 테이블을 만들었지만 행은 0건이다. 배정 풀이 비어 있으면 배정·완료 서비스는 물론
-- 업적(SPECIFIC_QUEST 조건)·칭호 설계도 참조할 대상이 없어 시작할 수 없다.
--
-- 퀘스트 ID는 계약이다. ACHIEVEMENTS.target_quest_id(팀원 3)가 특정 퀘스트를 가리키므로
-- AUTO_INCREMENT에 맡기지 않고 V3의 참조 데이터 시드와 같이 id를 명시한다. 아래 1~42는 고정이며,
-- 퀘스트를 내릴 때도 행을 지우지 말고 is_active=false로 바꾼다(docs/05-business-rules.md §11).
-- 행을 지우면 그 퀘스트를 조건으로 삼은 업적과 과거 완료 이력이 대상을 잃는다. 추가분은 43번부터 쓴다.
--
-- 등급 분포는 NORMAL 19 / RARE 14 / EPIC 7 / LEGENDARY 2다. 배정 확률(§2: 55/30/12/3)과 같은 비율일
-- 필요는 없지만 등급마다 후보가 있어야 확률 규칙이 성립한다. LEGENDARY 2건은 얇은 편이라
-- 3% 확률로 뽑힐 때 같은 퀘스트가 반복될 수 있다 — 배정 서비스 붙일 때 보강 여부를 판단한다.
--
-- 좌표는 시연·개발용 근사값이다. 각 장소의 대표 지점을 소수점 넷째 자리까지 적었고 미터 단위
-- 정밀도는 보장하지 않는다. 인증 반경(100~500m)이 이 오차를 흡수하도록 잡았지만, 운영 배포 전에는
-- 장소별 좌표를 실측으로 검증해야 한다. 반경은 §3-1의 구간(카페·음식점 50m / 공원·관광지 100m /
-- 산 등 넓은 장소 200~500m)에 맞췄고, 거리·시장처럼 지점이 아니라 구역인 곳은 한 단계 넓게 잡았다.
--
-- lifedex_item_id는 전부 NULL이다. LIFEDEX_ITEMS(팀원 3)가 아직 없어 연결할 대상이 없다.
-- 도감 연계의 자연스러운 후보는 LOCATION 퀘스트이며, 해당 테이블이 생기면 UPDATE로 잇는다.

-- 일간(DAILY) 24건 — 매일 반복하는 습관. NORMAL 19 / RARE 5.
-- LOCATION은 21~24번뿐이고 나머지는 이동 없이 끝낼 수 있다. 일간 퀘스트가 전부 위치 인증이면
-- 밖에 나가기 어려운 날 하루치 배정이 통째로 잠긴다.
INSERT INTO quests (
    id, title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    (1,  '물 여덟 잔 마시기', '하루 동안 물을 여덟 잔 이상 마셔 보세요.', 'NORMAL', 'DAILY', 'SELF_REPORT', 10,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (2,  '아침 스트레칭 10분', '일어나서 10분 동안 몸을 풀어 주세요.', 'NORMAL', 'DAILY', 'SELF_REPORT', 10,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (3,  '영양제 챙겨 먹기', '오늘 몫의 영양제를 잊지 말고 챙기세요.', 'NORMAL', 'DAILY', 'SELF_REPORT', 10,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (4,  '이불 정리하기', '일어나자마자 잠자리를 정돈해 보세요.', 'NORMAL', 'DAILY', 'SELF_REPORT', 10,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (5,  '6,000보 걷기', '오늘 하루 6,000보 이상 걸어 보세요.', 'NORMAL', 'DAILY', 'SELF_REPORT', 15,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (6,  '감사한 일 세 가지 적기', '오늘 고마웠던 일을 세 가지 적어 보세요.', 'NORMAL', 'DAILY', 'SELF_REPORT', 12,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (7,  '책 스무 쪽 읽기', '읽던 책을 스무 쪽만 더 넘겨 보세요.', 'NORMAL', 'DAILY', 'SELF_REPORT', 15,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (8,  '오늘 지출 기록하기', '오늘 쓴 돈을 빠짐없이 기록해 보세요.', 'NORMAL', 'DAILY', 'SELF_REPORT', 12,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (9,  '자기 전 휴대폰 멀리 두기', '잠들기 30분 전부터 휴대폰을 손이 닿지 않는 곳에 두세요.', 'NORMAL', 'DAILY', 'SELF_REPORT', 15,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (10, '한 끼는 채소로 채우기', '오늘 한 끼에는 채소를 꼭 곁들여 보세요.', 'NORMAL', 'DAILY', 'SELF_REPORT', 12,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (11, '책상 위 정리하기', '작업을 마치고 책상 위를 비워 보세요.', 'NORMAL', 'DAILY', 'SELF_REPORT', 10,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (12, '계단으로 오르기', '엘리베이터 대신 계단을 한 번 이용해 보세요.', 'NORMAL', 'DAILY', 'SELF_REPORT', 12,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (13, '오늘 배운 것 한 줄 정리', '오늘 새로 알게 된 것을 한 줄로 남겨 보세요.', 'NORMAL', 'DAILY', 'SELF_REPORT', 15,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (14, '창문 열고 환기하기', '10분만 창문을 활짝 열어 공기를 바꿔 보세요.', 'NORMAL', 'DAILY', 'SELF_REPORT', 10,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (15, '안 쓰는 물건 하나 비우기', '쓰지 않는 물건을 하나 골라 정리해 보세요.', 'NORMAL', 'DAILY', 'SELF_REPORT', 12,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (16, '안부 연락하기', '가족이나 친구에게 먼저 연락해 보세요.', 'NORMAL', 'DAILY', 'SELF_REPORT', 15,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (17, '10분 명상하기', '조용한 곳에서 10분 동안 호흡에 집중해 보세요.', 'NORMAL', 'DAILY', 'SELF_REPORT', 15,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (18, '오늘 사진 한 장 남기기', '오늘을 기억할 사진을 한 장 찍어 보세요.', 'NORMAL', 'DAILY', 'SELF_REPORT', 10,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (19, '동네 한 바퀴 산책하기', '집 근처를 20분 정도 천천히 걸어 보세요.', 'RARE', 'DAILY', 'SELF_REPORT', 30,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (20, '설거지 미루지 않기', '식사 후 설거지를 바로 끝내 보세요.', 'NORMAL', 'DAILY', 'SELF_REPORT', 10,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (21, '청계천 물길 따라 걷기', '청계광장에서 물길을 따라 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 35,
     '청계광장', 37.5696000, 126.9784000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (22, '도서관에서 30분 머물기', '서울도서관에서 30분 동안 책과 시간을 보내세요.', 'RARE', 'DAILY', 'LOCATION', 35,
     '서울도서관', 37.5663000, 126.9779000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (23, '한강에서 노을 보기', '반포한강공원에서 해 지는 하늘을 바라보세요.', 'RARE', 'DAILY', 'LOCATION', 40,
     '반포한강공원', 37.5109000, 126.9958000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (24, '아침 공원 산책하기', '서울숲에서 아침 공기를 마시며 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 30,
     '서울숲', 37.5444000, 127.0374000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 주간(WEEKLY) 12건 — 한 주에 한 번쯤 시간을 내는 활동. RARE 9 / EPIC 3.
INSERT INTO quests (
    id, title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    (25, '새로운 카페 방문하기', '가 본 적 없는 카페에 들러 한 잔 마셔 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '성수동 카페거리', 37.5445000, 127.0557000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (26, '전시 한 편 관람하기', '서울시립미술관에서 전시를 한 편 보고 오세요.', 'EPIC', 'WEEKLY', 'LOCATION', 60,
     '서울시립미술관', 37.5640000, 126.9738000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (27, '박물관에서 반나절 보내기', '국립중앙박물관을 천천히 둘러보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 70,
     '국립중앙박물관', 37.5240000, 126.9803000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (28, '고궁 산책하기', '경복궁 뜰을 한 바퀴 걸어 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 45,
     '경복궁', 37.5796000, 126.9770000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (29, '한옥 골목 걷기', '북촌한옥마을 골목을 따라 걸어 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '북촌한옥마을', 37.5826000, 126.9830000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (30, '전통시장에서 장 보기', '광장시장에서 먹거리나 찬거리를 사 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '광장시장', 37.5701000, 126.9997000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (31, '남산 전망대 오르기', '남산서울타워에서 도시를 내려다보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 65,
     '남산서울타워', 37.5512000, 126.9882000, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (32, '숲길 따라 걷기', '경의선숲길을 따라 산책해 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 45,
     '경의선숲길 연남동 구간', 37.5602000, 126.9250000, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (33, '주말 대청소하기', '한 주 동안 미뤄 둔 곳을 정리해 보세요.', 'RARE', 'WEEKLY', 'SELF_REPORT', 40,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (34, '한 주 지출 결산하기', '이번 주에 쓴 돈을 모아 정리해 보세요.', 'RARE', 'WEEKLY', 'SELF_REPORT', 35,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (35, '새로운 요리 만들기', '해 본 적 없는 요리를 한 가지 만들어 보세요.', 'RARE', 'WEEKLY', 'SELF_REPORT', 40,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (36, '한 주 회고 쓰기', '이번 주에 있었던 일을 돌아보며 적어 보세요.', 'RARE', 'WEEKLY', 'SELF_REPORT', 35,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 월간(MONTHLY) 6건 — 한 달에 한 번 마음먹고 하는 큰 도전. EPIC 4 / LEGENDARY 2.
INSERT INTO quests (
    id, title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    (37, '한 달 예산 점검하기', '지난 한 달의 수입과 지출을 정리하고 다음 달 예산을 세워 보세요.', 'EPIC', 'MONTHLY', 'SELF_REPORT', 80,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (38, '건강검진 다녀오기', '미뤄 둔 건강검진을 예약하고 다녀오세요.', 'EPIC', 'MONTHLY', 'SELF_REPORT', 90,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (39, '봉사활동 참여하기', '가까운 곳에서 봉사활동에 참여해 보세요.', 'LEGENDARY', 'MONTHLY', 'SELF_REPORT', 180,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (40, '북한산 백운대 오르기', '북한산 백운대 정상까지 올라 보세요.', 'LEGENDARY', 'MONTHLY', 'LOCATION', 250,
     '북한산 백운대', 37.6588000, 126.9779000, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (41, '올림픽공원 한 바퀴 걷기', '올림픽공원 둘레를 완주해 보세요.', 'EPIC', 'MONTHLY', 'LOCATION', 90,
     '올림픽공원', 37.5202000, 127.1216000, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (42, '서울식물원에서 반나절 보내기', '서울식물원의 온실과 호수원을 둘러보세요.', 'EPIC', 'MONTHLY', 'LOCATION', 100,
     '서울식물원', 37.5698000, 126.8350000, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));
