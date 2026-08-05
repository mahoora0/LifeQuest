-- 배정 생성 마커 (담당: 팀원 2 — 퀘스트 배정·완료·GPS 인증).
-- 결정 근거: personal/LifeQuest/Intent-Decisions/2026-08-04-quest-track-split-and-slot-design ②⑦
--
-- 배정은 지연 생성이다 — GET /quests/today가 해당 주기의 배정을 못 찾으면 그 자리에서 만든다.
-- 배치 스케줄러라는 새 인프라·장애점을 만들지 않고 완료 API의 락·멱등 설계를 그대로 재사용한다.
--
-- 그런데 지연 생성은 경합을 부른다. 같은 사용자가 앱을 두 번 빠르게 열면 두 요청이 모두
-- "배정 없음"을 보고 각각 생성을 시도한다. 기존 uk_user_daily_quests(user_id, quest_id,
-- assigned_date)는 이 경합을 막지 못한다 — 두 요청이 서로 다른 퀘스트를 뽑으면 겹치는 행이
-- 없어 제약에 걸리지 않고, 한 트랙에 6개가 배정되어 "트랙당 3개" 계약이 깨진다.
--
-- 그래서 생성 트랜잭션이 이 테이블에 행을 맨 먼저 INSERT한다. 유니크 위반이 나면 다른 요청이
-- 이미 만든 것이므로 생성을 포기하고 재조회로 돌아간다. 판정이 애플리케이션 조회가 아니라 DB
-- 제약이라 동시 요청에 안전하고 인스턴스를 늘려도 무력화되지 않는다(앱 레벨 락은 이 성질이 없다).
--
-- period_start는 트랙마다 의미가 다르며 user_daily_quests.assigned_date와 같은 값이다.
--   일간 → 논리적 일자(현재 시각 − 4시간의 날짜)
--   주간 → 그 주 월요일의 논리적 일자
-- 트랙을 키에 포함하는 이유는 갱신 주기가 서로 다르기 때문이다. 일간은 매일, 주간은 매주
-- 월요일에 새 행이 생긴다.
--
-- cadence를 VARCHAR에 담는 것은 V4·V5와 같은 이유다(H2 MySQL 모드/MySQL 양쪽 호환,
-- JPA @Enumerated STRING). 같은 이유로 CHECK 제약도 걸지 않는다.
--
-- user_id에 FK를 걸지 않는 이유는 V4의 user_daily_quests와 같다 — 크로스도메인 FK는 팀원 1의
-- 테이블에 제약을 만들므로 팀원 2가 단독으로 결정할 사안이 아니다.
CREATE TABLE quest_assignment_markers (
    id           BIGINT      NOT NULL AUTO_INCREMENT,
    user_id      BIGINT      NOT NULL,
    cadence      VARCHAR(20) NOT NULL,
    period_start DATE        NOT NULL,
    created_at   DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_quest_assignment_markers UNIQUE (user_id, cadence, period_start)
);
