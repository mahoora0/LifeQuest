-- 위치 퀘스트를 사용자 주변으로 배정하기 위한 두 컬럼군 (담당: 팀원 2 — 퀘스트 배정·완료·GPS 인증).
-- 배정 규칙 근거: docs/05-business-rules.md §1-A / 인증 반경: 같은 문서 §3-1.
--
-- 배경: quests의 좌표는 행에 고정돼 있고 시드는 전부 서울 명소다(V6). 배정 로직은 사용자 위치를
-- 보지 않으므로 서울 밖 사용자에게도 서울 좌표가 그대로 배정되고, 그 사용자는 슬롯 A(LOCATION)를
-- 영영 완료할 수 없다. V22 머리말이 이 결손을 "반경 확대와 지역 분산 중 어느 쪽으로 풀지 정해지면
-- 별도 마이그레이션으로 넣는다"고 미뤄 둔 자리이며, 이번에 둘을 함께 적용한다.
--
--   지역 분산 — 다른 도시 명소를 시드해 사용자와 가까운 것만 후보로 삼는다(V33).
--   반경 확대 — 시드된 도시가 주변에 하나도 없으면 장소를 특정하지 않는 템플릿 퀘스트를 배정하고,
--               좌표를 배정 시점에 사용자 주변으로 만들어 붙인다.

-- 장소를 특정하지 않는 퀘스트. 좌표가 "이 행의 값"이 아니라 "배정할 때 정해지는 값"임을 나타낸다.
--
-- BOOLEAN 컬럼을 따로 두는 이유는 좌표 NULL로는 이 구분을 못 하기 때문이다. LOCATION인데 좌표가
-- 없는 행은 ck_quests_location_verifiable이 거부하며, 그 제약은 유지해야 한다 — 좌표 없는 LOCATION이
-- 일반 경로로 들어오면 배정받은 사용자가 완료도 해제도 못 하는 상태에 빠진다(Quest 엔티티 주석 참조).
-- 템플릿 행도 좌표를 갖되(그 도시 대표 지점) 배정 시 override로 덮인다.
--
-- DEFAULT FALSE라 기존 68건은 전부 일반 퀘스트로 남는다.
ALTER TABLE quests ADD COLUMN is_location_template BOOLEAN NOT NULL DEFAULT FALSE;

-- 배정 시점에 정해진 좌표. NULL이면 퀘스트 원본의 좌표를 쓴다.
--
-- quests가 아니라 user_daily_quests에 두는 이유는 이 값이 사용자마다 다르기 때문이다. 원본 행을
-- 사용자별로 고쳐 쓰면 같은 템플릿을 배정받은 다른 사용자의 좌표를 덮어쓴다.
--
-- 완료 판정(QuestCompletionServiceImpl)과 지도 표시(/quests/nearby)가 모두 "override가 있으면
-- 그것, 없으면 원본" 순서로 읽는다. 판정과 표시가 같은 좌표를 봐야 사용자가 지도에서 본 지점에
-- 가서 인증에 성공한다 — 한쪽만 반영하면 화면과 판정이 어긋나고, 그 어긋남은 실제로 그 장소까지
-- 가 본 사용자에게만 드러난다.
--
-- 반경(radius_m)은 override 대상이 아니다. 인증 반경은 장소의 성격이 정하는 값이고(§3-1),
-- 템플릿 행이 이미 자기 반경을 갖고 있다.
ALTER TABLE user_daily_quests ADD COLUMN override_latitude DECIMAL(10, 7) NULL;
ALTER TABLE user_daily_quests ADD COLUMN override_longitude DECIMAL(10, 7) NULL;

-- 표시용 장소명. 템플릿은 "이 근처"처럼 지점을 특정하지 않는 이름을 쓰므로 원본 place_name을
-- 그대로 보여줘도 되지만, 실제 장소 API(카카오·구글 Places)로 좌표를 채우게 되면 그때는 조회된
-- 상호명이 여기 들어간다. 그 전환에서 스키마를 다시 건드리지 않으려고 지금 함께 만든다.
ALTER TABLE user_daily_quests ADD COLUMN override_place_name VARCHAR(100) NULL;
