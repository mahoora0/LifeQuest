-- 도감 전국 확장 (담당: 팀원 2 — 퀘스트 배정·완료·GPS 인증).
-- 범위 규칙: docs/05-business-rules.md §6-1 / 아이콘 키: docs/09-design-system.md §2 「도감 모티프」
--
-- V26이 만든 도감은 서울 15곳뿐이었고, quests.lifedex_item_id에 값을 넣는 문장도 그때의 한 줄
-- (V26의 UPDATE ... WHERE id IN (21..42))이 전부였다. 그 뒤 V33·V34가 위치 퀘스트를 전국
-- 206곳으로 넓혔지만 그 행들은 lifedex_item_id를 NULL로 넣었다. 그래서 <b>서울 밖 사용자는
-- 위치 퀘스트를 완료해도 도감이 비어 있었다</b> — 완료는 되고 EXP도 들어오는데 수집만 일어나지
-- 않아, 오류가 아니라 "연결이 없다"는 정상 동작으로 조용히 지나간다.
--
-- 여기서 실재 장소 위치 퀘스트 206건을 도감 항목으로 만들고 그 퀘스트에 연결한다.
-- 기존 15개 항목은 <b>건드리지 않는다</b> — 추가만 한다(id와 name이 바뀌면 시연 시더가
-- ORDER BY id로 고르는 퀘스트와 도감 항목이 함께 달라진다).
--
-- <b>항목 id를 원본 퀘스트 id로 삼는다.</b> V26이 정한 규약이고(그 파일 머리말), 여기서는 그것이
-- 편의가 아니라 필요다 — V34는 명시 id 없이 AUTO_INCREMENT로 적재되므로 퀘스트 id가 DB마다
-- 다르다. 항목을 리터럴로 적을 수 없고, 퀘스트에서 골라 넣어야 한다.
--
-- 고르는 조건은 아래 다섯이며 전부 이유가 있다.
--   completion_type = 'LOCATION'   도감은 "다녀온 장소"의 기록이다(§6-1)
--   is_location_template = FALSE   템플릿은 지점이 사용자마다 달라 수집 대상이 될 수 없다
--   created_by = 'SYSTEM'          관리자 등록분·AI 개인 퀘스트를 공용 카탈로그에 섞지 않는다
--   owner_user_id IS NULL          같은 이유. 개인 전용 행은 남의 도감에 나타나면 안 된다
--   lifedex_item_id IS NULL        이미 연결된 15건을 다시 넣지 않는다
-- cadence는 조건이 아니다 — 장소를 다녀왔다는 사실은 그 퀘스트가 일간인지 주간인지와 무관하다.
--
-- <b>장소명을 명시 목록으로 적는다.</b> 키워드 LIKE로 분류하지 않는 것은 V35가 같은 판단을 한
-- 이유와 같다 — '부산시민공원'에 '산'이 들어 있고 '테디베어뮤지엄 군산'도 그렇다. 접미어로
-- 좁혀도 '이중섭 거주지'가 '지'로 끝나 하천이 된다. 새 장소가 추가될 때 조용히 엉뚱한
-- 카테고리로 들어가느니 목록이 길어지는 편이 낫다.
--
-- 카테고리는 V26이 만든 6종을 그대로 쓴다. 지역 축(시·도)을 새로 만들면 카테고리 칩에
-- 장소 성격과 지역이 나란히 서서 축이 섞인다.
--
-- 분류는 장소의 성격으로 정했고, 이름만으로 성격이 드러나지 않는 17곳은 퀘스트 설명 문장을
-- 보고 정했다(예: '앞산공원'은 설명이 "등산로를 따라 전망대까지"라 산으로, '으능정이
-- 스카이로드'는 "아래의 거리를 걸어"라 골목으로 넣었다).
--
-- <b>icon_key는 V36이 만든 컬럼이고 어휘도 그쪽 계약이다.</b> 17종의 정본은 DB가 아니라 앱의
-- LqLifedexIcons이며(V36 머리말), 여기서는 그 키만 쓴다. 카테고리와 아이콘은 축이 다르므로
-- 하나가 다른 하나를 결정하지 않는다 — 수목원과 자연휴양림은 둘 다 park_forest지만 카테고리는
-- 각각 공원·산책로와 산·하천이고, 강변 공원은 카테고리가 공원·산책로인 채 waterside를 쓴다
-- (V36이 반포한강공원을 waterside로 둔 것과 같은 기준). 이름에 유형어가 그대로 든 것만 그렇게
-- 옮겼고, 근거가 이름에 없으면 park_city에 남겼다.
--
-- 적용 후 카탈로그
--   카페 2 · 공원 · 산책로 74 · 문화 · 전시 38 · 시장 · 골목 29 · 산 · 하천 44 · 역사 · 명소 34
--   합계 221 = 기존 15 + 신규 206 (= 실재 장소 위치 퀘스트 전량)
--   아이콘(V36의 15건 포함) = park_city 38 · heritage 32 · museum 29 · waterside 22 · trail 18
--            mountain 17 · street 15 · market 13 · park_forest 11 · beach 8 · gallery 7 · garden 4
--            cafe 2 · tower 2 · library 1 · hanok 1 · palace 1
--   library · hanok · palace 는 이 시드에 해당 장소가 없어 기존 15건에만 붙어 있다.
--
-- 내릴 때는 행을 지우지 말고 연결한 퀘스트를 is_active=false로 바꾼다(V6 머리말의 계약).

-- 카페 · 카페거리 → 카페 (1곳)
INSERT INTO lifedex_items (id, category_id, name, description, display_order, icon_key)
SELECT q.id, 1, q.place_name, CONCAT(q.place_name, '에 다녀온 기록'), q.id, 'cafe'
FROM quests q
WHERE q.completion_type = 'LOCATION' AND q.is_location_template = FALSE
  AND q.created_by = 'SYSTEM' AND q.owner_user_id IS NULL
  AND q.lifedex_item_id IS NULL
  AND q.place_name IN (
    '수암골 카페거리');

-- 도시공원 → 공원 · 산책로 (37곳)
INSERT INTO lifedex_items (id, category_id, name, description, display_order, icon_key)
SELECT q.id, 2, q.place_name, CONCAT(q.place_name, '에 다녀온 기록'), q.id, 'park_city'
FROM quests q
WHERE q.completion_type = 'LOCATION' AND q.is_location_template = FALSE
  AND q.created_by = 'SYSTEM' AND q.owner_user_id IS NULL
  AND q.lifedex_item_id IS NULL
  AND q.place_name IN (
    '부산시민공원', '송도 센트럴파크', '인천대공원', '5·18기념공원', '낙산공원', '매탄공원', '대모산도시자연공원', '상희공원', '성라공원',
    '용인중앙공원', '부천 중앙공원', '화랑유원지', '약대울체육공원', '다산중앙공원', '신대레포츠공원', '부락산분수공원', '상당공원', '문암생태공원',
    '중앙탑공원', '신방공원', '숲뜰근린공원', '세병공원', '둔산공원', '거북선공원', '여수 가사리 생태공원', '노을공원', '구영공원', '용지공원',
    '만날근린공원', '모산공원', '물초울공원', '덕수공원', '환호공원', '경주축구공원', '장미공원', '신산공원', '자구리문화예술공원');

-- 숲길 · 둘레길 → 공원 · 산책로 (17곳)
INSERT INTO lifedex_items (id, category_id, name, description, display_order, icon_key)
SELECT q.id, 2, q.place_name, CONCAT(q.place_name, '에 다녀온 기록'), q.id, 'trail'
FROM quests q
WHERE q.completion_type = 'LOCATION' AND q.is_location_template = FALSE
  AND q.created_by = 'SYSTEM' AND q.owner_user_id IS NULL
  AND q.lifedex_item_id IS NULL
  AND q.place_name IN (
    '대청호 오백리길', '계족산 황톳길', '서울로7017', '노송지대', '경춘선숲길', '박두진문학길', '봉황경', '에코힐링 황톳길', '곡교천 은행나무길',
    '경천애인 징검다리길', '유달산 둘레길', '은하수 다리', '선성수상길', '봄내길 7코스', '연세대 원주캠퍼스길', '벗고개', '노추산 모정탑길');

-- 강 · 천변 · 호수 → 공원 · 산책로 (10곳)
INSERT INTO lifedex_items (id, category_id, name, description, display_order, icon_key)
SELECT q.id, 2, q.place_name, CONCAT(q.place_name, '에 다녀온 기록'), q.id, 'waterside'
FROM quests q
WHERE q.completion_type = 'LOCATION' AND q.is_location_template = FALSE
  AND q.created_by = 'SYSTEM' AND q.owner_user_id IS NULL
  AND q.lifedex_item_id IS NULL
  AND q.place_name IN (
    '경안천 습지생태공원', '강서습지생태공원', '궁동저수지 생태공원', '세종호수공원', '금강습지생태공원', '조례호수공원', '금호못유원지',
    '길안천지생태공원', '춘천시 수변공원', '경포호수광장');

-- 식물원 · 정원 → 공원 · 산책로 (3곳)
INSERT INTO lifedex_items (id, category_id, name, description, display_order, icon_key)
SELECT q.id, 2, q.place_name, CONCAT(q.place_name, '에 다녀온 기록'), q.id, 'garden'
FROM quests q
WHERE q.completion_type = 'LOCATION' AND q.is_location_template = FALSE
  AND q.created_by = 'SYSTEM' AND q.owner_user_id IS NULL
  AND q.lifedex_item_id IS NULL
  AND q.place_name IN (
    '계양산장미원', '가야정원', '금강식물원');

-- 숲 · 수목원 · 휴양림 → 공원 · 산책로 (2곳)
INSERT INTO lifedex_items (id, category_id, name, description, display_order, icon_key)
SELECT q.id, 2, q.place_name, CONCAT(q.place_name, '에 다녀온 기록'), q.id, 'park_forest'
FROM quests q
WHERE q.completion_type = 'LOCATION' AND q.is_location_template = FALSE
  AND q.created_by = 'SYSTEM' AND q.owner_user_id IS NULL
  AND q.lifedex_item_id IS NULL
  AND q.place_name IN (
    '대구수목원', '한밭수목원');

-- 박물관 → 문화 · 전시 (28곳)
INSERT INTO lifedex_items (id, category_id, name, description, display_order, icon_key)
SELECT q.id, 3, q.place_name, CONCAT(q.place_name, '에 다녀온 기록'), q.id, 'museum'
FROM quests q
WHERE q.completion_type = 'LOCATION' AND q.is_location_template = FALSE
  AND q.created_by = 'SYSTEM' AND q.owner_user_id IS NULL
  AND q.lifedex_item_id IS NULL
  AND q.place_name IN (
    '국립대구박물관', '국립중앙과학관', '경기도행정역사관', '경기여고 경운박물관', '김달진미술자료박물관', '예아리박물관', '성호박물관', '남양주시립박물관',
    '한국교원대학교 교육박물관', '수안보곤충박물관', '천안박물관', '대전선사박물관', '국립전주박물관', '테디베어뮤지엄 군산', '순천시 기독교역사박물관',
    '세계화석광물박물관', '울산 옹기박물관', '김씨박물관', '김해목재문화박물관', '진주청동기문화박물관', '영일민속박물관', '한국대중음악박물관',
    '경상북도 산림과학박물관', '모형항공기박물관', '고판화박물관', '소금강 돌박물관', '테디베어하우스 테지움', '제주항공우주박물관');

-- 미술관 · 전시관 → 문화 · 전시 (6곳)
INSERT INTO lifedex_items (id, category_id, name, description, display_order, icon_key)
SELECT q.id, 3, q.place_name, CONCAT(q.place_name, '에 다녀온 기록'), q.id, 'gallery'
FROM quests q
WHERE q.completion_type = 'LOCATION' AND q.is_location_template = FALSE
  AND q.created_by = 'SYSTEM' AND q.owner_user_id IS NULL
  AND q.lifedex_item_id IS NULL
  AND q.place_name IN (
    '인천상륙작전기념관', '국립아시아문화전당', '광주시립미술관', '광명업사이클아트센터', '평택농업전시관', '이순신대교홍보관');

-- 전망 타워 → 문화 · 전시 (1곳)
INSERT INTO lifedex_items (id, category_id, name, description, display_order, icon_key)
SELECT q.id, 3, q.place_name, CONCAT(q.place_name, '에 다녀온 기록'), q.id, 'tower'
FROM quests q
WHERE q.completion_type = 'LOCATION' AND q.is_location_template = FALSE
  AND q.created_by = 'SYSTEM' AND q.owner_user_id IS NULL
  AND q.lifedex_item_id IS NULL
  AND q.place_name IN (
    '이월드 83타워');

-- 거리 · 골목 → 시장 · 골목 (15곳)
INSERT INTO lifedex_items (id, category_id, name, description, display_order, icon_key)
SELECT q.id, 4, q.place_name, CONCAT(q.place_name, '에 다녀온 기록'), q.id, 'street'
FROM quests q
WHERE q.completion_type = 'LOCATION' AND q.is_location_template = FALSE
  AND q.created_by = 'SYSTEM' AND q.owner_user_id IS NULL
  AND q.lifedex_item_id IS NULL
  AND q.place_name IN (
    '감천문화마을', '김광석 다시그리기길', '월미도', '인천 차이나타운', '으능정이 스카이로드', '양림동 근대역사문화마을', '나혜석거리', '성내동 관아골',
    '전주 동문예술거리', '우체통거리', '순천 문화의거리', '장미의거리', '경주 금리단길', '두맹이골목', '이중섭거리');

-- 시장 · 먹거리 골목 → 시장 · 골목 (12곳)
INSERT INTO lifedex_items (id, category_id, name, description, display_order, icon_key)
SELECT q.id, 4, q.place_name, CONCAT(q.place_name, '에 다녀온 기록'), q.id, 'market'
FROM quests q
WHERE q.completion_type = 'LOCATION' AND q.is_location_template = FALSE
  AND q.created_by = 'SYSTEM' AND q.owner_user_id IS NULL
  AND q.lifedex_item_id IS NULL
  AND q.place_name IN (
    '자갈치시장', '서문시장', '소래포구', '서현시범 맛집거리', '일산 대화동 먹자골목', '까치울음식테마마을', '댕이골 전통음식거리', '낭만포차거리',
    '마산 오동동 아구찜거리', '글로벌푸드타운', '안동시장 찜닭골목', '춘천 명동 닭갈비 골목');

-- 산 · 정상 → 산 · 하천 (16곳)
INSERT INTO lifedex_items (id, category_id, name, description, display_order, icon_key)
SELECT q.id, 5, q.place_name, CONCAT(q.place_name, '에 다녀온 기록'), q.id, 'mountain'
FROM quests q
WHERE q.completion_type = 'LOCATION' AND q.is_location_template = FALSE
  AND q.created_by = 'SYSTEM' AND q.owner_user_id IS NULL
  AND q.lifedex_item_id IS NULL
  AND q.place_name IN (
    '앞산공원', '관악산', '도드람산', '계양산', '관음사국기봉', '구녀산', '보련산', '광덕산', '노고산', '간월산', '마금산', '금정산',
    '경주 낭산', '삼악산', '둔지봉', '미악산');

-- 강 · 천변 · 호수 → 산 · 하천 (10곳)
INSERT INTO lifedex_items (id, category_id, name, description, display_order, icon_key)
SELECT q.id, 5, q.place_name, CONCAT(q.place_name, '에 다녀온 기록'), q.id, 'waterside'
FROM quests q
WHERE q.completion_type = 'LOCATION' AND q.is_location_template = FALSE
  AND q.created_by = 'SYSTEM' AND q.owner_user_id IS NULL
  AND q.lifedex_item_id IS NULL
  AND q.place_name IN (
    '광주호 호수생태원', '용덕저수지', '배다리지', '금남 백로 서식지', '월명호수', '무안회산백련지', '진양호 일주도로', '백운동계곡',
    '구룡소 돌개구멍', '순포습지');

-- 숲 · 수목원 · 휴양림 → 산 · 하천 (8곳)
INSERT INTO lifedex_items (id, category_id, name, description, display_order, icon_key)
SELECT q.id, 5, q.place_name, CONCAT(q.place_name, '에 다녀온 기록'), q.id, 'park_forest'
FROM quests q
WHERE q.completion_type = 'LOCATION' AND q.is_location_template = FALSE
  AND q.created_by = 'SYSTEM' AND q.owner_user_id IS NULL
  AND q.lifedex_item_id IS NULL
  AND q.place_name IN (
    '장태산자연휴양림', '국립아세안자연휴양림', '독산성산림욕장', '국제광림비전랜드', '두동편백나무숲', '광양 옥룡사 동백나무 숲', '덕동생태숲',
    '붉은오름자연휴양림');

-- 바다 · 해변 → 산 · 하천 (8곳)
INSERT INTO lifedex_items (id, category_id, name, description, display_order, icon_key)
SELECT q.id, 5, q.place_name, CONCAT(q.place_name, '에 다녀온 기록'), q.id, 'beach'
FROM quests q
WHERE q.completion_type = 'LOCATION' AND q.is_location_template = FALSE
  AND q.created_by = 'SYSTEM' AND q.owner_user_id IS NULL
  AND q.lifedex_item_id IS NULL
  AND q.place_name IN (
    '광안리해수욕장', '해운대해수욕장', '태종대', '향일암 해안길', '간절곶 소망길', '구룡포 주상절리', '사천진항', '곽지해수욕장');

-- 유적 · 향교 · 서원 · 사찰 → 역사 · 명소 (32곳)
INSERT INTO lifedex_items (id, category_id, name, description, display_order, icon_key)
SELECT q.id, 6, q.place_name, CONCAT(q.place_name, '에 다녀온 기록'), q.id, 'heritage'
FROM quests q
WHERE q.completion_type = 'LOCATION' AND q.is_location_template = FALSE
  AND q.created_by = 'SYSTEM' AND q.owner_user_id IS NULL
  AND q.lifedex_item_id IS NULL
  AND q.place_name IN (
    '무등산 증심사', '문헌서원', '둔촌이집묘역', '월산대군사당', '용인향교', '류순정·류홍 부자 묘역', '사세충렬문', '남양주 구 팔당역', '평택향교',
    '청주향교', '충주 김생사지', '불당동 유적공원', '연기향교', '전라 감영', '군산 신흥동 일본식가옥', '여수 선소유적', '순천향교',
    '이난영의 목포의 눈물 노래비', '용연서원', '운암서원', '김해 봉황동 유적', '진주향교', '연일향교', '경주 굴불사지 석조사면불상', '경주 서출지',
    '안동 고성이씨 탑동파 종택', '영호루', '춘천향교', '원주향교', '강릉향교', '귤림서원', '이중섭 거주지');
-- 방금 만든 항목을 원본 퀘스트에 연결한다. 항목 id가 곧 퀘스트 id이므로 조건이 곧 대상이다.
-- 기존 15건은 lifedex_item_id가 이미 채워져 있어 IS NULL에서 걸러진다.
UPDATE quests SET lifedex_item_id = id
WHERE lifedex_item_id IS NULL
  AND id IN (SELECT id FROM lifedex_items);

-- 도감이 전국이 되면서 칭호 이름 둘이 사실과 어긋난다. V27은 이미 적용된 파일이라 고칠 수
-- 없으므로(체크섬) 여기서 이름만 바꾼다. 획득 조건과 code는 그대로다.
UPDATE titles SET name = '전국 생활대백과' WHERE code = 'LIFEDEX_COMPLETE';
UPDATE titles SET name = '능선 수집가' WHERE code = 'LIFEDEX_NATURE_COMPLETE';
