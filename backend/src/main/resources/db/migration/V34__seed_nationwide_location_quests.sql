-- 전국 지역 LOCATION 시드 174건 (담당: 팀원 2 — 퀘스트 배정·완료·GPS 인증).
-- 등급·EXP 기준: docs/05-business-rules.md §2 / 인증 반경: 같은 문서 §3-1 / 슬롯: 같은 문서 §1-A.
--
-- 출처: 한국관광공사 국문 관광정보 서비스(TourAPI, 공공데이터포털 15101578), 2026-08-13 수집.
-- 이용 조건에 따라 출처를 밝힌다. 장소명·좌표·분류를 그 API에서 받았고, 퀘스트 제목과 설명은
-- 분류별 문장 틀에 장소명을 넣어 만들었다.
--
-- V33은 서울과 5대 광역시를 덮었다. 그 밖의 사용자는 실재 장소를 하나도 받지 못하고 장소
-- 미지정 템플릿(101~105)만 배정되는데, 템플릿은 사용자 주변 몇백 미터에 지점을 만들어 주므로
-- 완료는 되지만 "어디에 가서 무엇을 한다"는 내용이 없다. 여기서 그 결손을 29개 도시로 넓힌다.
--
-- 대상 도시는 수도권 8(수원·성남·고양·용인·부천·안산·남양주·평택) · 충청 4(청주·충주·천안·세종)
-- · 호남 5(전주·군산·여수·순천·목포) · 영남 7(울산·창원·김해·진주·포항·경주·안동)
-- · 강원 3(춘천·원주·강릉) · 제주 2(제주·서귀포)다. 울산은 광역시인데 V33에서 빠져 있었다.
--
-- 도시마다 일간 NORMAL·RARE·EPIC 각 1건, 주간 RARE·EPIC·LEGENDARY 각 1건을 넣는다. V33이 쓴
-- 구성과 같으며, 이유도 같다 — 배정이 사용자 주변으로 후보를 좁히므로 좁힌 뒤의 등급 분포를
-- 정하는 것은 카탈로그 전체가 아니라 그 도시의 구성이다.
--
-- 장소는 다음을 만족하는 것만 골랐다. 퀘스트는 "가서 무언가 하고 GPS로 인증한다"이기 때문이다.
--   · 예약·입장료·장비 없이 갈 수 있다 (야영장·골프장·낚시터·수련시설·온천을 뺀 이유)
--   · 영업시간이나 공연 일정에 매이지 않는다 (공연장을 뺀 이유)
--   · 지점이 오래 유지된다 (숙박·상업시설을 뺀 이유)
--
-- 등급은 장소 성격이 요구하는 이동과 소요시간으로 정했다. 공원·수목원은 일간 NORMAL,
-- 거리·물가는 일간 RARE, 유적지·사찰은 일간 EPIC, 박물관·전시관은 주간 RARE,
-- 생태·휴양림·해변은 주간 EPIC, 산·둘레길은 주간 LEGENDARY다.
--
-- 좌표는 API가 준 값을 그대로 쓴다. 반경은 §3-1 구간에 맞췄고, 지점이 아니라 구역인 곳
-- (산·해변·둘레길)은 한 단계 넓게 잡았다.
--
-- 기존 시드와 1km 안에 겹치는 장소는 뺐다. 같은 곳이 두 번 들어가면 그 도시 사용자가 이름만
-- 다른 같은 장소를 두 번 배정받는다.
--
-- <b>id를 적지 않고 AUTO_INCREMENT에 맡긴다.</b> 앞선 시드(V6·V22·V33)와 다른 점이며 이유가 있다.
--
-- 주간 AI 퀘스트가 개인 전용 행을 같은 quests 테이블에 AUTO_INCREMENT로 넣는다
-- (Quest.createPrivateAiWeekly). 그래서 AI 추천을 한 번이라도 받은 DB는 id가 이미 100번대를
-- 넘어서 있고, 거기에 명시 id 시드를 적용하면 duplicate key로 Flyway가 죽는다. 팀원마다 DB
-- 상태가 달라 어떤 사람에게만 부팅이 실패하는 형태이고, CI와 H2는 매번 새 DB라 통과하므로
-- 테스트로는 드러나지 않는다.
--
-- 명시 id가 필요했던 이유는 ACHIEVEMENTS.target_quest_id가 특정 퀘스트를 가리키기 때문인데,
-- 그 참조는 id 1~42에만 걸려 있다. 이 시드는 업적이 가리키지 않으므로 번호를 고정할 이유가 없다.
--
-- 대신 시드 가드가 id 범위가 아니라 <b>좌표와 장소</b>로 검사한다 — 어차피 배정이 보는 것도
-- 좌표이지 id가 아니다.
--
-- 내릴 때는 행을 지우지 말고 is_active=false로 바꾼다(V6 머리말의 계약은 그대로다).
--
-- lifedex_item_id는 전부 NULL이다. 도감 연계는 팀원 3의 항목 정의를 받은 뒤 UPDATE로 한다.


-- 수원(경기) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('매탄공원 한 바퀴 걷기', '매탄공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '매탄공원', 37.2669819, 127.0459039, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('나혜석거리 끝까지 걸어 보기', '나혜석거리를 끝에서 끝까지 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '나혜석거리', 37.2640209, 127.0344383, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('문헌서원 둘러보기', '문헌서원에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '문헌서원', 37.1743011, 127.0534586, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('경기도행정역사관 전시 보기', '경기도행정역사관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '경기도행정역사관', 37.3135116, 126.9894216, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('대모산도시자연공원 생태길 걷기', '대모산도시자연공원의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '대모산도시자연공원', 37.4800522, 127.0810141, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('노송지대 천천히 걷기', '노송지대를 처음부터 끝까지 천천히 걸어 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '노송지대', 37.3160529, 126.9871162, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 성남(경기) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('상희공원 한 바퀴 걷기', '상희공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '상희공원', 37.4109419, 127.1411856, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('서현시범 맛집거리 끝까지 걸어 보기', '서현시범 맛집거리를 끝에서 끝까지 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '서현시범 맛집거리', 37.3844059, 127.1309595, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('둔촌이집묘역 둘러보기', '둔촌이집묘역에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '둔촌이집묘역', 37.4282790, 127.1540812, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('경기여고 경운박물관 전시 보기', '경기여고 경운박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '경기여고 경운박물관', 37.4867512, 127.0656765, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('경안천 습지생태공원 생태길 걷기', '경안천 습지생태공원의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '경안천 습지생태공원', 37.4573533, 127.3032168, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('관악산 올라 보기', '관악산의 등산로를 따라 올라 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '관악산', 37.4484036, 126.9540988, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 고양(경기) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('성라공원 한 바퀴 걷기', '성라공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '성라공원', 37.6510530, 126.8399146, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('일산 대화동 먹자골목 끝까지 걸어 보기', '일산 대화동 먹자골목을 끝에서 끝까지 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '일산 대화동 먹자골목', 37.6781539, 126.7547911, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('월산대군사당 둘러보기', '월산대군사당에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '월산대군사당', 37.6760924, 126.8735553, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('김달진미술자료박물관 전시 보기', '김달진미술자료박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '김달진미술자료박물관', 37.6001055, 126.9566637, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('강서습지생태공원 생태길 걷기', '강서습지생태공원의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '강서습지생태공원', 37.5860880, 126.8171491, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('국립아세안자연휴양림에서 쉬어 가기', '국립아세안자연휴양림의 숲길을 걷고 잠시 쉬어 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '국립아세안자연휴양림', 37.7738767, 126.9421934, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 용인(경기) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('용인중앙공원 한 바퀴 걷기', '용인중앙공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '용인중앙공원', 37.2317639, 127.2083985, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('용덕저수지 물길 따라 걷기', '용덕저수지를 따라 이어진 길을 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '용덕저수지', 37.1848501, 127.2251177, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('용인향교 둘러보기', '용인향교에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '용인향교', 37.2955354, 127.1201936, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('예아리박물관 전시 보기', '예아리박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '예아리박물관', 37.1422048, 127.3629731, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('독산성산림욕장에서 쉬어 가기', '독산성산림욕장의 숲길을 걷고 잠시 쉬어 보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '독산성산림욕장', 37.1807997, 127.0180588, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('도드람산 올라 보기', '도드람산의 등산로를 따라 올라 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '도드람산', 37.2676519, 127.3925169, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 부천(경기) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('부천 중앙공원 한 바퀴 걷기', '부천 중앙공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '부천 중앙공원', 37.5006581, 126.7637286, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('까치울음식테마마을 끝까지 걸어 보기', '까치울음식테마마을을 끝에서 끝까지 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '까치울음식테마마을', 37.5151517, 126.8138125, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('류순정·류홍 부자 묘역 둘러보기', '류순정·류홍 부자 묘역에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '류순정·류홍 부자 묘역', 37.4887162, 126.8293840, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('광명업사이클아트센터에서 그림 보기', '광명업사이클아트센터에서 마음에 남는 작품을 하나 찾아보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '광명업사이클아트센터', 37.4625589, 126.8729447, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('계양산장미원 생태길 걷기', '계양산장미원의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '계양산장미원', 37.5471018, 126.7127514, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('계양산 올라 보기', '계양산의 등산로를 따라 올라 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '계양산', 37.5502377, 126.7234086, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 안산(경기) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('화랑유원지 한 바퀴 걷기', '화랑유원지를 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '화랑유원지', 37.3267819, 126.8124401, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('댕이골 전통음식거리 끝까지 걸어 보기', '댕이골 전통음식거리를 끝에서 끝까지 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '댕이골 전통음식거리', 37.2946806, 126.8422855, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('사세충렬문 둘러보기', '사세충렬문에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '사세충렬문', 37.3374004, 126.8305715, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('성호박물관 전시 보기', '성호박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '성호박물관', 37.3151258, 126.8595917, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('궁동저수지 생태공원 생태길 걷기', '궁동저수지 생태공원의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '궁동저수지 생태공원', 37.5012175, 126.8293198, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('관음사국기봉 올라 보기', '관음사국기봉의 등산로를 따라 올라 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '관음사국기봉', 37.4403515, 126.9383144, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 남양주(경기) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('약대울체육공원 한 바퀴 걷기', '약대울체육공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '약대울체육공원', 37.6515711, 127.2305762, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('다산중앙공원 한 바퀴 걷기', '다산중앙공원을 천천히 한 바퀴 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '다산중앙공원', 37.6251563, 127.1597834, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('남양주 구 팔당역 둘러보기', '남양주 구 팔당역에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '남양주 구 팔당역', 37.5443145, 127.2487915, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('남양주시립박물관 전시 보기', '남양주시립박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '남양주시립박물관', 37.5464392, 127.2443918, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('국제광림비전랜드에서 쉬어 가기', '국제광림비전랜드의 숲길을 걷고 잠시 쉬어 보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '국제광림비전랜드', 37.6801952, 127.3642160, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('경춘선숲길 끝까지 걷기', '경춘선숲길의 나무 사이 길을 끝까지 걸어 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '경춘선숲길', 37.6316233, 127.0694164, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 평택(경기) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('신대레포츠공원 한 바퀴 걷기', '신대레포츠공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '신대레포츠공원', 36.9940499, 127.0655152, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('배다리지 물길 따라 걷기', '배다리지를 따라 이어진 길을 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '배다리지', 37.0002501, 127.1185158, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('평택향교 둘러보기', '평택향교에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '평택향교', 36.9654558, 127.0560336, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('평택농업전시관 전시 보기', '평택농업전시관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '평택농업전시관', 37.0143905, 126.9808612, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('부락산분수공원 생태길 걷기', '부락산분수공원의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '부락산분수공원', 37.0661083, 127.0707267, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('박두진문학길 완주하기', '박두진문학길을 처음부터 끝까지 걸어 완주해 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '박두진문학길', 36.9938798, 127.3369852, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 청주(충북) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('상당공원 한 바퀴 걷기', '상당공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '상당공원', 36.6369069, 127.4911507, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('수암골 카페거리 끝까지 걸어 보기', '수암골 카페거리를 끝에서 끝까지 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '수암골 카페거리', 36.6450449, 127.4949668, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('청주향교 둘러보기', '청주향교에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '청주향교', 36.6373403, 127.4969057, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('한국교원대학교 교육박물관 전시 보기', '한국교원대학교 교육박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '한국교원대학교 교육박물관', 36.6056581, 127.3573191, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('문암생태공원 생태길 걷기', '문암생태공원의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '문암생태공원', 36.6745490, 127.4478174, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('구녀산 올라 보기', '구녀산의 등산로를 따라 올라 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '구녀산', 36.7008712, 127.6133491, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 충주(충북) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('중앙탑공원 한 바퀴 걷기', '중앙탑공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '중앙탑공원', 37.0178922, 127.8662091, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('성내동 관아골 끝까지 걸어 보기', '성내동 관아골을 끝에서 끝까지 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '성내동 관아골', 36.9707683, 127.9345293, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('충주 김생사지 둘러보기', '충주 김생사지에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '충주 김생사지', 37.0063304, 127.9081695, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('수안보곤충박물관 전시 보기', '수안보곤충박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '수안보곤충박물관', 36.8543523, 127.9999545, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('봉황경 생태길 걷기', '봉황경의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '봉황경', 37.0780489, 127.8517198, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('보련산 올라 보기', '보련산의 등산로를 따라 올라 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '보련산', 37.0512698, 127.7658532, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 천안(충남) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('에코힐링 황톳길 한 바퀴 걷기', '에코힐링 황톳길을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '에코힐링 황톳길', 36.7978342, 127.0979066, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('신방공원 한 바퀴 걷기', '신방공원을 천천히 한 바퀴 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '신방공원', 36.7852721, 127.1204383, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('불당동 유적공원 둘러보기', '불당동 유적공원에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '불당동 유적공원', 36.8039393, 127.1149660, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('천안박물관 전시 보기', '천안박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '천안박물관', 36.7867172, 127.1632094, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('곡교천 은행나무길 생태길 걷기', '곡교천 은행나무길의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '곡교천 은행나무길', 36.7995464, 127.0168278, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('광덕산 올라 보기', '광덕산의 등산로를 따라 올라 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '광덕산', 36.6759000, 127.0423233, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 세종(세종) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('숲뜰근린공원 한 바퀴 걷기', '숲뜰근린공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '숲뜰근린공원', 36.4674501, 127.2649145, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('세종호수공원 한 바퀴 걷기', '세종호수공원을 천천히 한 바퀴 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '세종호수공원', 36.4989994, 127.2701993, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('연기향교 둘러보기', '연기향교에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '연기향교', 36.5433917, 127.2811665, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('대전선사박물관 전시 보기', '대전선사박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '대전선사박물관', 36.3718399, 127.3238951, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('금남 백로 서식지 생태길 걷기', '금남 백로 서식지의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '금남 백로 서식지', 36.4424479, 127.2909156, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('노고산 올라 보기', '노고산의 등산로를 따라 올라 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '노고산', 36.4241507, 127.4891623, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 전주(전북) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('세병공원 한 바퀴 걷기', '세병공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '세병공원', 35.8768680, 127.1307950, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('전주 동문예술거리 끝까지 걸어 보기', '전주 동문예술거리를 끝에서 끝까지 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '전주 동문예술거리', 35.8211691, 127.1498198, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('전라 감영 둘러보기', '전라 감영에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '전라 감영', 35.8157780, 127.1455842, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('국립전주박물관 전시 보기', '국립전주박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '국립전주박물관', 35.8013231, 127.0897201, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('둔산공원 생태길 걷기', '둔산공원의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '둔산공원', 35.9630442, 127.1289151, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('경천애인 징검다리길 완주하기', '경천애인 징검다리길을 처음부터 끝까지 걸어 완주해 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '경천애인 징검다리길', 36.0210065, 127.2517888, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 군산(전북) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('월명호수 한 바퀴 걷기', '월명호수를 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '월명호수', 35.9791126, 126.6901789, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('우체통거리 끝까지 걸어 보기', '우체통거리를 끝에서 끝까지 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '우체통거리', 35.9854901, 126.7123879, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('군산 신흥동 일본식가옥 둘러보기', '군산 신흥동 일본식가옥에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '군산 신흥동 일본식가옥', 35.9863010, 126.7061578, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('테디베어뮤지엄 군산 전시 보기', '테디베어뮤지엄 군산에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '테디베어뮤지엄 군산', 35.9855706, 126.7095409, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('금강습지생태공원 생태길 걷기', '금강습지생태공원의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '금강습지생태공원', 36.0224284, 126.7670487, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('두동편백나무숲 끝까지 걷기', '두동편백나무숲의 나무 사이 길을 끝까지 걸어 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '두동편백나무숲', 36.1037857, 126.9214355, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 여수(전남) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('거북선공원 한 바퀴 걷기', '거북선공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '거북선공원', 34.7606283, 127.6667404, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('낭만포차거리 끝까지 걸어 보기', '낭만포차거리를 끝에서 끝까지 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '낭만포차거리', 34.7365852, 127.7495171, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('여수 선소유적 둘러보기', '여수 선소유적에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '여수 선소유적', 34.7582066, 127.6795199, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('이순신대교홍보관 관람하기', '이순신대교홍보관의 전시를 처음부터 끝까지 보고 오세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '이순신대교홍보관', 34.8892424, 127.7046949, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('여수 가사리 생태공원 생태길 걷기', '여수 가사리 생태공원의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '여수 가사리 생태공원', 34.7483396, 127.5944942, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('향일암 해안길 완주하기', '향일암 해안길을 처음부터 끝까지 걸어 완주해 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '향일암 해안길', 34.5938216, 127.8030244, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 순천(전남) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('조례호수공원 한 바퀴 걷기', '조례호수공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '조례호수공원', 34.9660833, 127.5220340, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('순천 문화의거리 끝까지 걸어 보기', '순천 문화의거리를 끝에서 끝까지 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '순천 문화의거리', 34.9546923, 127.4827571, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('순천향교 둘러보기', '순천향교에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '순천향교', 34.9539729, 127.4795519, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('순천시 기독교역사박물관 전시 보기', '순천시 기독교역사박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '순천시 기독교역사박물관', 34.9604749, 127.4801794, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('가야정원 숲길 걷기', '가야정원의 나무들을 보며 산책로를 걸어 보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '가야정원', 34.8619089, 127.5222505, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('광양 옥룡사 동백나무 숲 끝까지 걷기', '광양 옥룡사 동백나무 숲의 나무 사이 길을 끝까지 걸어 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '광양 옥룡사 동백나무 숲', 35.0461203, 127.6092270, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 목포(전남) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('노을공원 한 바퀴 걷기', '노을공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '노을공원', 34.8089955, 126.3657758, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('장미의거리 끝까지 걸어 보기', '장미의거리를 끝에서 끝까지 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '장미의거리', 34.8022583, 126.4257707, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('이난영의 목포의 눈물 노래비 찾아가기', '이난영의 목포의 눈물 노래비 앞에 서서 새겨진 글을 읽어 보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '이난영의 목포의 눈물 노래비', 34.7872481, 126.3742645, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('세계화석광물박물관 전시 보기', '세계화석광물박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '세계화석광물박물관', 34.7162860, 126.1691482, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('무안회산백련지 생태길 걷기', '무안회산백련지의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '무안회산백련지', 34.8601257, 126.5299101, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('유달산 둘레길 완주하기', '유달산 둘레길을 처음부터 끝까지 걸어 완주해 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '유달산 둘레길', 34.7973274, 126.3693563, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 울산(울산) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('구영공원 한 바퀴 걷기', '구영공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '구영공원', 35.5708102, 129.2420171, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('은하수 다리 건너 보기', '은하수 다리를 걸어서 건너 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '은하수 다리', 35.5500133, 129.2834752, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('용연서원 둘러보기', '용연서원에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '용연서원', 35.5476723, 129.3045095, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('울산 옹기박물관 전시 보기', '울산 옹기박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '울산 옹기박물관', 35.4350595, 129.2795176, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('간절곶 소망길 생태길 걷기', '간절곶 소망길의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '간절곶 소망길', 35.3546337, 129.3492111, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('간월산 올라 보기', '간월산의 등산로를 따라 올라 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '간월산', 35.5561610, 129.0480650, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 창원(경남) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('용지공원 한 바퀴 걷기', '용지공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '용지공원', 35.2293467, 128.6871083, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('마산 오동동 아구찜거리 끝까지 걸어 보기', '마산 오동동 아구찜거리를 끝에서 끝까지 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '마산 오동동 아구찜거리', 35.2030754, 128.5759215, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('운암서원 둘러보기', '운암서원에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '운암서원', 35.2412277, 128.6356320, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('김씨박물관 전시 보기', '김씨박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '김씨박물관', 35.1292345, 128.7762671, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('만날근린공원 생태길 걷기', '만날근린공원의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '만날근린공원', 35.1852269, 128.5494993, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('마금산 올라 보기', '마금산의 등산로를 따라 올라 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '마금산', 35.3540033, 128.6028762, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 김해(경남) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('모산공원 한 바퀴 걷기', '모산공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '모산공원', 35.1673116, 128.8219455, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('글로벌푸드타운 끝까지 걸어 보기', '글로벌푸드타운을 끝에서 끝까지 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '글로벌푸드타운', 35.2350329, 128.8822939, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('김해 봉황동 유적 둘러보기', '김해 봉황동 유적에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '김해 봉황동 유적', 35.2310721, 128.8750558, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('김해목재문화박물관 전시 보기', '김해목재문화박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '김해목재문화박물관', 35.1800988, 128.8081602, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('금강식물원 숲길 걷기', '금강식물원의 나무들을 보며 산책로를 걸어 보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '금강식물원', 35.2264764, 129.0770633, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('금정산 올라 보기', '금정산의 등산로를 따라 올라 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '금정산', 35.2684490, 129.0518588, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 진주(경남) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('금호못유원지 한 바퀴 걷기', '금호못유원지를 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '금호못유원지', 35.2144860, 128.1543220, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('진양호 일주도로 물가 걷기', '진양호 일주도로의 물가를 따라 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '진양호 일주도로', 35.1762326, 128.0350390, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('진주향교 둘러보기', '진주향교에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '진주향교', 35.1976062, 128.0926140, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('진주청동기문화박물관 전시 보기', '진주청동기문화박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '진주청동기문화박물관', 35.2253036, 127.9627302, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('물초울공원 생태길 걷기', '물초울공원의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '물초울공원', 35.1829949, 128.1457514, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('백운동계곡 계곡 따라 걷기', '백운동계곡을 따라 물소리를 들으며 걸어 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '백운동계곡', 35.2963414, 127.8835964, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 포항(경북) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('덕수공원 한 바퀴 걷기', '덕수공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '덕수공원', 36.0459923, 129.3643484, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('환호공원 한 바퀴 걷기', '환호공원을 천천히 한 바퀴 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '환호공원', 36.0677293, 129.3930425, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('연일향교 둘러보기', '연일향교에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '연일향교', 36.0065071, 129.3235420, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('영일민속박물관 전시 보기', '영일민속박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '영일민속박물관', 36.1108457, 129.3472452, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('구룡소 돌개구멍 생태길 걷기', '구룡소 돌개구멍의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '구룡소 돌개구멍', 36.0568302, 129.5251368, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('구룡포 주상절리 해안 걷기', '구룡포 주상절리의 해안을 따라 걸어 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '구룡포 주상절리', 35.9985876, 129.5681958, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 경주(경북) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('경주축구공원 한 바퀴 걷기', '경주축구공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '경주축구공원', 35.8602409, 129.2113283, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('경주 금리단길 끝까지 걸어 보기', '경주 금리단길을 끝에서 끝까지 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '경주 금리단길', 35.8420236, 129.2148313, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('경주 굴불사지 석조사면불상 둘러보기', '경주 굴불사지 석조사면불상에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '경주 굴불사지 석조사면불상', 35.8578721, 129.2303433, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('한국대중음악박물관 전시 보기', '한국대중음악박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '한국대중음악박물관', 35.8403557, 129.2888915, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('경주 서출지 생태길 걷기', '경주 서출지의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '경주 서출지', 35.7964431, 129.2424274, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('경주 낭산 올라 보기', '경주 낭산의 등산로를 따라 올라 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '경주 낭산', 35.8232429, 129.2423294, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 안동(경북) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('안동 고성이씨 탑동파 종택 마루에 앉아 보기', '안동 고성이씨 탑동파 종택을 둘러보고 마루에 잠시 앉아 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '안동 고성이씨 탑동파 종택', 36.5663298, 128.7467129, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('안동시장 찜닭골목 끝까지 걸어 보기', '안동시장 찜닭골목을 끝에서 끝까지 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '안동시장 찜닭골목', 36.5652601, 128.7285478, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('영호루 둘러보기', '영호루에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '영호루', 36.5527364, 128.7219710, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('경상북도 산림과학박물관 전시 보기', '경상북도 산림과학박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '경상북도 산림과학박물관', 36.7141838, 128.8236184, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('길안천지생태공원 생태길 걷기', '길안천지생태공원의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '길안천지생태공원', 36.4560758, 128.8983526, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('선성수상길 완주하기', '선성수상길을 처음부터 끝까지 걸어 완주해 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '선성수상길', 36.6995158, 128.8123448, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 춘천(강원) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('춘천시 수변공원 한 바퀴 걷기', '춘천시 수변공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '춘천시 수변공원', 37.8725791, 127.7003020, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('춘천 명동 닭갈비 골목 끝까지 걸어 보기', '춘천 명동 닭갈비 골목을 끝에서 끝까지 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '춘천 명동 닭갈비 골목', 37.8800898, 127.7284297, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('춘천향교 둘러보기', '춘천향교에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '춘천향교', 37.8815537, 127.7341264, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('모형항공기박물관 전시 보기', '모형항공기박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '모형항공기박물관', 37.7517010, 127.8222222, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('봄내길 7코스 생태길 걷기', '봄내길 7코스의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '봄내길 7코스', 37.8158566, 127.6326681, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('삼악산 올라 보기', '삼악산의 등산로를 따라 올라 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '삼악산', 37.8257699, 127.6593321, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 원주(강원) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('장미공원 한 바퀴 걷기', '장미공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '장미공원', 37.3470165, 127.9307410, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('연세대 원주캠퍼스길 끝까지 걸어 보기', '연세대 원주캠퍼스길을 끝에서 끝까지 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '연세대 원주캠퍼스길', 37.2815544, 127.9154220, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('원주향교 둘러보기', '원주향교에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '원주향교', 37.3387123, 127.9494645, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('고판화박물관 전시 보기', '고판화박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '고판화박물관', 37.2571334, 128.1286980, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('덕동생태숲에서 쉬어 가기', '덕동생태숲의 숲길을 걷고 잠시 쉬어 보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '덕동생태숲', 37.2140712, 127.9520485, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('벗고개 넘어 보기', '벗고개를 걸어서 넘어 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '벗고개', 37.5020254, 127.7311517, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 강릉(강원) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('경포호수광장 한 바퀴 걷기', '경포호수광장을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '경포호수광장', 37.7977914, 128.9095225, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('사천진항에서 바닷바람 쐬기', '사천진항에 들러 바닷바람을 맞아 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '사천진항', 37.8368418, 128.8782046, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('강릉향교 둘러보기', '강릉향교에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '강릉향교', 37.7635562, 128.8952470, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('소금강 돌박물관 전시 보기', '소금강 돌박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '소금강 돌박물관', 37.8481875, 128.7261458, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('순포습지 생태길 걷기', '순포습지의 길을 따라 걸으며 주변을 살펴보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '순포습지', 37.8204550, 128.8875265, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('노추산 모정탑길 완주하기', '노추산 모정탑길을 처음부터 끝까지 걸어 완주해 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '노추산 모정탑길', 37.5709532, 128.7407252, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 제주(제주) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('신산공원 한 바퀴 걷기', '신산공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '신산공원', 33.5052799, 126.5337916, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('두맹이골목 끝까지 걸어 보기', '두맹이골목을 끝에서 끝까지 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '두맹이골목', 33.5120458, 126.5349219, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('귤림서원 둘러보기', '귤림서원에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '귤림서원', 33.5060575, 126.5276032, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('테디베어하우스 테지움 전시 보기', '테디베어하우스 테지움에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '테디베어하우스 테지움', 33.4120435, 126.3935836, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('곽지해수욕장 모래사장 걷기', '곽지해수욕장의 모래사장을 따라 걸어 보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '곽지해수욕장', 33.4485353, 126.3031046, 300, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('둔지봉 올라 보기', '둔지봉의 등산로를 따라 올라 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '둔지봉', 33.5012457, 126.7973021, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 서귀포(제주) —— 일간 3 / 주간 3
INSERT INTO quests (
    title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    ('자구리문화예술공원 한 바퀴 걷기', '자구리문화예술공원을 천천히 한 바퀴 걸어 보세요.', 'NORMAL', 'DAILY', 'LOCATION', 15,
     '자구리문화예술공원', 33.2419429, 126.5675085, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('이중섭거리 끝까지 걸어 보기', '이중섭거리를 끝에서 끝까지 걸어 보세요.', 'RARE', 'DAILY', 'LOCATION', 32,
     '이중섭거리', 33.2455202, 126.5644698, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('이중섭 거주지 둘러보기', '이중섭 거주지에 남아 있는 흔적을 천천히 둘러보세요.', 'EPIC', 'DAILY', 'LOCATION', 47,
     '이중섭 거주지', 33.2455758, 126.5644170, 200, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('제주항공우주박물관 전시 보기', '제주항공우주박물관에서 전시를 하나 골라 천천히 보세요.', 'RARE', 'WEEKLY', 'LOCATION', 40,
     '제주항공우주박물관', 33.3043706, 126.2996275, 100, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('붉은오름자연휴양림에서 쉬어 가기', '붉은오름자연휴양림의 숲길을 걷고 잠시 쉬어 보세요.', 'EPIC', 'WEEKLY', 'LOCATION', 75,
     '붉은오름자연휴양림', 33.3952749, 126.6742708, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    ('미악산 올라 보기', '미악산의 등산로를 따라 올라 보세요.', 'LEGENDARY', 'WEEKLY', 'LOCATION', 200,
     '미악산', 33.3005945, 126.5542194, 500, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));
