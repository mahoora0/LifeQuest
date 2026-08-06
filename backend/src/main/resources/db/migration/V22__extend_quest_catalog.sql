-- 퀘스트 카탈로그 확장 26건 (담당: 팀원 2 — 퀘스트 배정·완료·GPS 인증).
-- 등급·EXP 기준: docs/05-business-rules.md §2 / 슬롯 구성: 같은 문서 §1-A.
--
-- 슬롯은 타입을 먼저 고정한 뒤 그 풀 안에서 등급 확률을 정규화해 뽑는다(§1-A). 어떤 트랙·타입
-- 조합에 특정 등급 후보가 0건이면 그 등급의 확률이 0으로 재배분되어 영영 나오지 않는다.
-- 확장 전 결손은 둘이었다.
--
--   일간 SELF_REPORT : EPIC 0 · LEGENDARY 0  — 일간에서는 상위 등급이 나올 수 없었다
--   주간 SELF_REPORT : NORMAL 0 · EPIC 0     — 주간 슬롯 B가 RARE와 LEGENDARY만 오갔다
--
-- 이번 확장은 전부 SELF_REPORT다. LOCATION 결손(일간 LOCATION이 RARE 4건뿐이라 슬롯 A가 항상
-- RARE다)은 분리한다 — quests는 좌표를 행에 고정하는데 사용자마다 가까운 장소가 달라, 가벼운
-- 근거리 퀘스트를 시드 좌표 하나로는 다룰 수 없다. 반경 확대와 지역 분산 중 어느 쪽으로 풀지
-- 정해지면 별도 마이그레이션으로 넣는다.
--
-- id는 43번부터다. 1~42를 지우지 않는 계약(V6 머리말)은 확장분에도 적용한다 — 내릴 때는 행을
-- 지우지 말고 is_active=false로 바꾼다.
--
-- 67·68은 일간 완료 개수를 조건으로 삼아 두 트랙을 잇는다. 완료 판정은 다른 SELF_REPORT와 같이
-- 사용자 신고에 맡긴다. 시스템 집계로 바꾸려면 완료 트랜잭션이 연쇄 완료를 다뤄야 하고
-- (EXP_LOGS의 UNIQUE(user_id, source_type, source_id)가 두 완료를 어떻게 구분할지 포함),
-- 그 설계는 아직 없다.
--
-- EXP 값 일부가 §2의 등급별 범위 밖에 있다 — 일간 EPIC 45~50과 주간 NORMAL 25~28이 그렇다.
-- 트랙이 보상 대역을 정하고 등급이 그 대역 안에서 위치를 정하는 방향이며, §2 표는 밸런싱과 함께
-- 갱신한다. exp_reward에 대한 값 제약은 DB에도 코드에도 없다.
--
-- 좌표·반경 컬럼은 전부 NULL이다. SELF_REPORT는 V4의 ck_quests_location_verifiable 대상이 아니다.
-- lifedex_item_id도 NULL이다 — LIFEDEX_ITEMS(팀원 3)가 아직 없다.
--
-- 확장 후 분포 (활성 66건)
--   일간 37 — NORMAL 19 / RARE 11 / EPIC 4 / LEGENDARY 3
--   주간 29 — NORMAL 4 / RARE 10 / EPIC 10 / LEGENDARY 5

-- 일간(DAILY) 13건 — 기존 일간이 NORMAL 19 / RARE 5로 상위 등급이 비어 있었다.
INSERT INTO quests (
    id, title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    (43, '90분 몰입 작업', '알림을 모두 끄고 한 가지 일에만 90분 동안 매달려 보세요.', 'RARE', 'DAILY', 'SELF_REPORT', 35,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (44, '미룬 일 하나 끝내기', '일주일 넘게 미뤄 둔 일을 하나 골라 오늘 안에 끝내 보세요.', 'RARE', 'DAILY', 'SELF_REPORT', 33,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (45, '30분 달리기', '자기 속도로 30분 동안 쉬지 말고 달려 보세요.', 'RARE', 'DAILY', 'SELF_REPORT', 32,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (46, '30분 필사하기', '마음에 드는 글을 골라 30분 동안 손으로 옮겨 적어 보세요.', 'RARE', 'DAILY', 'SELF_REPORT', 32,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (47, '자정 전에 잠들기', '오늘은 자정을 넘기지 말고 잠자리에 들어 보세요.', 'RARE', 'DAILY', 'SELF_REPORT', 30,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (48, '하루 카페인 끊기', '오늘 하루만 커피 없이 지내 보세요.', 'RARE', 'DAILY', 'SELF_REPORT', 30,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (49, '하루 디지털 디톡스', '오늘 하루는 SNS와 영상 앱을 열지 않고 지내 보세요.', 'EPIC', 'DAILY', 'SELF_REPORT', 50,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (50, '옷장 전부 정리하기', '옷을 모두 꺼내 입을 것과 보낼 것을 나눠 보세요.', 'EPIC', 'DAILY', 'SELF_REPORT', 48,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (51, '하루 무지출로 보내기', '오늘 하루는 한 푼도 쓰지 않고 지내 보세요.', 'EPIC', 'DAILY', 'SELF_REPORT', 46,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (52, '휴대폰 사진 정리하기', '쌓인 사진과 파일을 훑어보고 필요 없는 것을 지워 보세요.', 'EPIC', 'DAILY', 'SELF_REPORT', 45,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (53, '헌혈하기', '가까운 헌혈의집에 들러 헌혈에 참여해 보세요.', 'LEGENDARY', 'DAILY', 'SELF_REPORT', 60,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (54, '1년 뒤 나에게 편지 쓰기', '지금의 마음을 담아 1년 뒤에 열어 볼 편지를 써 보세요.', 'LEGENDARY', 'DAILY', 'SELF_REPORT', 56,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (55, '해돋이 보러 가기', '새벽에 일어나 가까운 곳에서 해 뜨는 순간을 지켜보세요.', 'LEGENDARY', 'DAILY', 'SELF_REPORT', 55,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));

-- 주간(WEEKLY) 13건 — 기존 주간에 NORMAL이 없어 슬롯 B의 하단이 비어 있었다.
-- 67·68은 일간 완료 개수를 조건으로 삼는다. 일간은 주당 21개가 배정되므로 10개는 절반가량,
-- 15개는 70%가량의 완료를 요구한다.
INSERT INTO quests (
    id, title, description, grade, cadence, completion_type, exp_reward,
    place_name, latitude, longitude, radius_m, lifedex_item_id,
    created_by, is_active, created_at
) VALUES
    (56, '한 주 식단 계획하기', '다음 한 주 동안 먹을 끼니를 미리 정해 보세요.', 'NORMAL', 'WEEKLY', 'SELF_REPORT', 28,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (57, '침구 세탁하기', '베개와 이불 커버를 걷어 한 번 빨아 보세요.', 'NORMAL', 'WEEKLY', 'SELF_REPORT', 27,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (58, '냉장고 정리하기', '냉장고를 열어 오래된 식재료를 골라내 보세요.', 'NORMAL', 'WEEKLY', 'SELF_REPORT', 27,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (59, '재활용 분리배출 하기', '한 주 동안 모인 재활용품을 분류해 배출해 보세요.', 'NORMAL', 'WEEKLY', 'SELF_REPORT', 25,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (60, '온라인 강의 수료하기', '무료 온라인 강좌를 하나 골라 이번 주 안에 끝까지 들어 보세요.', 'EPIC', 'WEEKLY', 'SELF_REPORT', 80,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (61, '주 3회 운동하기', '이번 주에 세 번, 땀이 날 만큼 몸을 움직여 보세요.', 'EPIC', 'WEEKLY', 'SELF_REPORT', 78,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (62, '안 쓰는 물건 나눔하기', '쓰지 않는 물건을 모아 필요한 곳에 보내 보세요.', 'EPIC', 'WEEKLY', 'SELF_REPORT', 75,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (63, '일주일 치 반찬 만들기', '다음 한 주 동안 먹을 반찬을 미리 만들어 두세요.', 'EPIC', 'WEEKLY', 'SELF_REPORT', 72,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (64, '응급처치 교육 이수하기', '가까운 소방서나 적십자의 심폐소생술 교육을 신청해 이수해 보세요.', 'LEGENDARY', 'WEEKLY', 'SELF_REPORT', 220,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (65, '10km 걸어서 완주하기', '하루를 잡고 10km를 걸어서 완주해 보세요.', 'LEGENDARY', 'WEEKLY', 'SELF_REPORT', 200,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (66, '공모전에 응모하기', '관심 가는 공모전을 찾아 이번 주 안에 응모까지 마쳐 보세요.', 'LEGENDARY', 'WEEKLY', 'SELF_REPORT', 200,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (67, '일간 퀘스트 10개 완료', '이번 주에 일간 퀘스트를 열 개 이상 끝내 보세요.', 'RARE', 'WEEKLY', 'SELF_REPORT', 40,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6)),
    (68, '일간 퀘스트 15개 완료', '이번 주에 일간 퀘스트를 열다섯 개 이상 끝내 보세요.', 'EPIC', 'WEEKLY', 'SELF_REPORT', 75,
     NULL, NULL, NULL, NULL, NULL, 'SYSTEM', TRUE, CURRENT_TIMESTAMP(6));