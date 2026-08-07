-- 주간 AI 퀘스트 슬롯 (담당: 팀원 2 — 퀘스트 배정·완료 / 팀원 4 — LLM 추천).
-- 근거: docs/05-business-rules.md §1(배정)·§1-A(슬롯) / docs/04-api-spec.md §3.
--
-- 주간 트랙의 슬롯 C를 자동 추출에서 빼고 사용자가 AI 추천 중에서 직접 고르게 한다.
--
--   주간 ├ 슬롯 A  자동 LOCATION
--        ├ 슬롯 B  자동 SELF_REPORT
--        └ 슬롯 C  사용자가 고른 AI SELF_REPORT   ← 이 마이그레이션이 여는 자리
--
-- 일간은 그대로 자동 3개다. 트랙별 슬롯 구성이 갈리는 첫 사례이며, 구성 자체는
-- QuestAssignmentCreator가 코드로 들고 있다(스키마에 슬롯 개념이 없다).

-- 1. 개인 소유 퀘스트 -----------------------------------------------------------
--
-- USER_DAILY_QUESTS.quest_id에 FK가 걸려 있어(V4 fk_udq_quest) 배정에 들어가려면 반드시
-- QUESTS 행이어야 한다. 그래서 AI 후보도 선택되는 순간 QUESTS 행이 된다.
--
-- 문제는 배정 풀이다. QuestRepository.findByActiveTrue()가 활성 퀘스트 전체를 가져오므로
-- 개인 AI 퀘스트를 그냥 넣으면 다른 사용자의 주간 추첨 풀에 섞인다 — 내가 만든 "제주 3박"이
-- 남에게 배정된다. owner_user_id로 공용/개인을 가르고 풀 조회는 NULL만 본다.
--
--   owner_user_id IS NULL      시스템·관리자가 만든 공용 카탈로그(배정 풀 대상)
--   owner_user_id IS NOT NULL  특정 사용자 전용 AI 퀘스트(그 사용자에게만 보인다)
--
-- 여기에 "이번 주에 슬롯을 썼는가"는 넣지 않는다. QUESTS는 배정·완료가 참조하는 원본 정의이고,
-- 특정 주의 선택 상태는 선택 이력의 책임이다. 그 제약은 아래 weekly_ai_quest_claims가 진다.
ALTER TABLE quests ADD COLUMN owner_user_id BIGINT NULL;

-- 완료 가이드 — "무엇을 하면 완료로 볼 것인가". SELF_REPORT는 시스템이 판정하지 않으므로
-- 이 문장이 사용자에게 유일한 완료 기준이다. AI 후보에는 completionGuide가 있는데 QUESTS에
-- 담을 자리가 없어 description(500자)에 이어 붙이면 잘릴 수 있다.
--
-- 공용 퀘스트는 NULL이다. 지금은 AI 퀘스트만 쓰지만 컬럼 자체는 생성 주체와 무관하며,
-- 나중에 시드 퀘스트에 완료 기준을 붙일 때 그대로 쓸 수 있다.
ALTER TABLE quests ADD COLUMN completion_guide VARCHAR(300) NULL;

-- created_by와 owner_user_id는 함께 움직인다. AI 퀘스트인데 주인이 없으면 아무에게도 배정될 수
-- 없는 채로 풀에서도 빠진 고아 행이 되고, 공용인데 주인이 있으면 그 사용자에게만 보이는 카탈로그
-- 퀘스트가 된다. 둘 다 조용히 잘못되는 종류라 애플리케이션(Quest.requireAiOwnership)과 DB
-- 양쪽에서 막는다 — V4의 ck_quests_location_verifiable과 같은 이유다.
ALTER TABLE quests ADD CONSTRAINT ck_quests_ai_owner CHECK (
    (created_by = 'AI' AND owner_user_id IS NOT NULL)
    OR (created_by <> 'AI' AND owner_user_id IS NULL)
);

-- 배정 풀 조회(findByActiveTrueAndOwnerUserIdIsNull)가 매 트랙 생성마다 돈다.
CREATE INDEX idx_quests_owner ON quests (owner_user_id, is_active);

-- 2. 추천 후보 보관 ------------------------------------------------------------
--
-- 지금까지 추천 결과는 응답으로만 나가고 사라졌다. 그 상태로 "선택"을 붙이면 앱이 후보 내용을
-- 되돌려 보내야 하는데, 그러면 제목·완료 가이드는 물론 무엇이든 앱에서 바꿔 보낼 수 있다.
-- Validator가 예산·기간을 검증하는 의미가 사라진다. 그래서 검증을 통과한 후보를 저장하고
-- 선택은 candidate_id로만 받는다.
--
-- 저장은 주간 추천 경로에서만 한다. 일반 place/travel 추천은 지금처럼 저장하지 않는다 —
-- 구경만 하는 요청까지 쌓으면 이 테이블이 쓰이지 않을 행으로 채워진다.
--
-- period_start는 후보가 어느 주를 위해 만들어졌는지다. 일요일 23:00에 받은 후보를 월요일
-- 05:00에 고르면 논리적 주가 넘어가 있으므로(주기 경계 04:00) 그 후보는 더 이상 유효하지 않다.
-- 만료를 시각이 아니라 주기로 표현하는 이유는 주간 배정의 만료가 그렇게 정의돼 있기 때문이다.
CREATE TABLE quest_recommendation_candidates (
    id                        BIGINT       NOT NULL AUTO_INCREMENT,
    user_id                   BIGINT       NOT NULL,
    period_start              DATE         NOT NULL,
    recommendation_type       VARCHAR(20)  NOT NULL,
    title                     VARCHAR(100) NOT NULL,
    description               VARCHAR(500) NOT NULL,
    category                  VARCHAR(20)  NOT NULL,
    duration_value            INT          NOT NULL,
    duration_unit             VARCHAR(20)  NOT NULL,
    estimated_cost_per_person INT          NOT NULL,
    suggested_place_name      VARCHAR(100) NOT NULL,
    completion_guide          VARCHAR(300) NOT NULL,
    claimed_at                DATETIME(6)  NULL,
    created_at                DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_qrc_user FOREIGN KEY (user_id) REFERENCES users (id)
);
CREATE INDEX idx_qrc_owner_period ON quest_recommendation_candidates (user_id, period_start);

-- 3. 주당 1회 보장 -------------------------------------------------------------
--
-- 제약 두 개가 서로 다른 것을 지킨다.
--
--   uk_weekly_ai_claim_period     한 사용자가 한 주에 하나만 고른다
--   uk_weekly_ai_claim_candidate  하나의 후보는 정확히 한 번만 소비된다
--
-- 두 번째를 candidates.claimed_at으로 대신하지 않는다. claimed_at은 애플리케이션이 쓰는 상태라
-- 조회와 갱신 사이에 창이 있고, UNIQUE는 DB 불변식이라 동시 요청에도 창이 없다.
--
-- quest_id·user_daily_quest_id는 두지 않는다. 선택된 AI 퀘스트는 quests.owner_user_id와
-- user_daily_quests.assigned_date로 찾을 수 있어 파생 가능하고, 컬럼을 비워두면 claim을
-- 트랜잭션 맨 앞에서 INSERT할 수 있다 — V19가 마커에 대해 적은 것과 같은 이유로, 판정을
-- 조회가 아니라 제약 위반으로 하려면 쓰기가 먼저 와야 한다.
--
-- (재시도 멱등성 — 서버는 성공했는데 응답이 끊겨 앱이 같은 요청을 다시 보내는 경우 — 을 완전히
-- 다루려면 user_daily_quest_id가 있어야 같은 성공 응답을 재구성할 수 있다. 지금은 409를 주고
-- 앱이 목록을 새로 부르는 것으로 충분하다고 보고 뺐다.)
CREATE TABLE weekly_ai_quest_claims (
    id           BIGINT      NOT NULL AUTO_INCREMENT,
    user_id      BIGINT      NOT NULL,
    period_start DATE        NOT NULL,
    candidate_id BIGINT      NOT NULL,
    created_at   DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_weekly_ai_claim_period UNIQUE (user_id, period_start),
    CONSTRAINT uk_weekly_ai_claim_candidate UNIQUE (candidate_id),
    CONSTRAINT fk_waqc_candidate FOREIGN KEY (candidate_id)
        REFERENCES quest_recommendation_candidates (id)
);
