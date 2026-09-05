-- 도감 항목·카테고리에 장소 모티프 아이콘 키를 붙인다 (담당: 팀원 2 — 도감 아트).
-- 그림·키 목록·규칙: docs/09-design-system.md §2 「도감 모티프」.
--
-- 항목마다 그림을 한 장씩 두지 않고 <b>장소 유형</b>을 가리키게 한 이유가 있다.
-- 도감 항목 수가 열려 있기 때문이다. 지금은 15개지만 전국 위치 퀘스트 시드
-- (V33 37건 · V34 174건)가 도감으로 올라오면 수백 개가 된다. 그때 항목마다
-- 새 그림이 필요하면 도감 확장은 아트 작업량에 묶이고, 그 작업이 밀리는 동안
-- 확장 자체가 멈춘다. 유형은 17종으로 닫히므로 새 항목은 기존 키를 재사용하면
-- 되고, 그림을 새로 그리는 것은 없던 유형이 등장할 때뿐이다.
--
-- 키 규칙
--   · snake_case, 소문자·숫자·밑줄만 (^[a-z][a-z0-9_]*$)
--   · app/assets/images/icons/lifedex/<키>.svg 파일명과 1:1
--   · NULL 허용 — 항목이 비면 앱이 카테고리 키로 물러난다
--   · 앱이 모르는 키를 넣어도 화면은 깨지지 않는다. 키 목록의 정본은
--     LqLifedexIcons(app/lib/shared/design/lq_assets.dart)이고, 조회에 실패하면
--     카테고리 모티프로 물러난다. 그래서 시드와 그림이 다른 순서로 들어와도 된다.
--
-- 여기서는 <b>열을 더하고 값을 채우기만 한다.</b> 기존 항목의 id·name은 건드리지
-- 않는다 — 시연 영상이 id 23(반포한강공원)의 도장 장면에 걸려 있고, 업적
-- (achievements.target_quest_id)이 id 1~42를 참조한다.

ALTER TABLE lifedex_categories ADD COLUMN icon_key VARCHAR(40) NULL;
ALTER TABLE lifedex_items ADD COLUMN icon_key VARCHAR(40) NULL;

-- 카테고리는 그 분류에서 가장 흔한 유형을 대표로 삼는다. 카테고리 그리드(S-13)가
-- 이 값으로 그려지고, 항목이 자기 키를 갖지 않을 때 물러날 자리이기도 하다.
UPDATE lifedex_categories SET icon_key = 'cafe'      WHERE id = 1; -- 카페
UPDATE lifedex_categories SET icon_key = 'park_city' WHERE id = 2; -- 공원 · 산책로
UPDATE lifedex_categories SET icon_key = 'museum'    WHERE id = 3; -- 문화 · 전시
UPDATE lifedex_categories SET icon_key = 'market'    WHERE id = 4; -- 시장 · 골목
UPDATE lifedex_categories SET icon_key = 'mountain'  WHERE id = 5; -- 산 · 하천
UPDATE lifedex_categories SET icon_key = 'palace'    WHERE id = 6; -- 역사 · 명소

-- 항목 15건. id로 짚는다 — 이름이 아니라 id가 계약이다.
UPDATE lifedex_items SET icon_key = 'cafe'        WHERE id = 25; -- 성수동 카페거리
UPDATE lifedex_items SET icon_key = 'waterside'   WHERE id = 23; -- 반포한강공원
UPDATE lifedex_items SET icon_key = 'park_forest' WHERE id = 24; -- 서울숲
UPDATE lifedex_items SET icon_key = 'trail'       WHERE id = 32; -- 경의선숲길
UPDATE lifedex_items SET icon_key = 'park_city'   WHERE id = 41; -- 올림픽공원
UPDATE lifedex_items SET icon_key = 'garden'      WHERE id = 42; -- 서울식물원
UPDATE lifedex_items SET icon_key = 'library'     WHERE id = 22; -- 서울도서관
UPDATE lifedex_items SET icon_key = 'gallery'     WHERE id = 26; -- 서울시립미술관
UPDATE lifedex_items SET icon_key = 'museum'      WHERE id = 27; -- 국립중앙박물관
UPDATE lifedex_items SET icon_key = 'hanok'       WHERE id = 29; -- 북촌한옥마을
UPDATE lifedex_items SET icon_key = 'market'      WHERE id = 30; -- 광장시장
UPDATE lifedex_items SET icon_key = 'waterside'   WHERE id = 21; -- 청계천
UPDATE lifedex_items SET icon_key = 'mountain'    WHERE id = 40; -- 북한산 백운대
UPDATE lifedex_items SET icon_key = 'palace'      WHERE id = 28; -- 경복궁
UPDATE lifedex_items SET icon_key = 'tower'       WHERE id = 31; -- 남산서울타워
