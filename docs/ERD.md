# Life Quest — ERD

MVP 범위([PRD](./PRD.md) §4) 테이블. 팀원1~4의 실제 담당 표(User/Quest/UserQuest · Location/Region/QuestLocation · Level/Achievement/LifeDex/Title · Friend/Reward/Ranking/Inventory)를 정규화해 관계와 제약을 명시한다.

> 성향 벡터·동행 매칭 등 확장 엔진 테이블(Disposition, MatchPool, CoopRoom, SecretRule)은 **Phase 2**로 이 ERD에 없음. 상세는 `docs/life-quest-design.html` 참조.

```mermaid
%%{init: {'theme':'neutral'}}%%
erDiagram
  USER ||--o{ USER_QUEST : receives
  QUEST ||--o{ USER_QUEST : instanced_as
  QUEST ||--o| QUEST_LOCATION : requires
  QUEST_LOCATION }o--|| LOCATION : targets
  LOCATION }o--|| REGION : belongs_to

  USER ||--o{ USER_ACHIEVEMENT : progresses
  ACHIEVEMENT ||--o{ USER_ACHIEVEMENT : tracked_by
  USER ||--o{ LIFEDEX_ENTRY : collects
  USER ||--o{ USER_TITLE : unlocks
  TITLE ||--o{ USER_TITLE : granted_as

  USER ||--o{ FRIENDSHIP : requests
  USER ||--o{ REWARD_LOG : receives
  USER ||--o{ INVENTORY : owns
  USER ||--o{ RANKING_SNAPSHOT : ranked_in

  USER {
    bigint id PK
    string email UK
    string nickname
    int level
    bigint exp
    bigint equipped_title_id FK
  }
  QUEST {
    bigint id PK
    string title
    string category
    string tier "일반|희귀|영웅|전설"
    int exp_reward
    int min_level
  }
  QUEST_LOCATION {
    bigint quest_id PK_FK
    bigint location_id FK
    int radius_m "예시 100"
  }
  LOCATION {
    bigint id PK
    bigint region_id FK
    decimal lat
    decimal lng
    string source "TourAPI 등"
  }
  REGION {
    bigint id PK
    string name
  }
  USER_QUEST {
    bigint id PK
    bigint user_id FK
    bigint quest_id FK
    date assigned_date
    string status "ASSIGNED|COMPLETED|EXPIRED"
    datetime verified_at "위치 인증 시각, nullable"
    datetime completed_at
    string idempotency_key UK
  }
  ACHIEVEMENT {
    bigint id PK
    string code
    string name
    int tier_thresholds "예: 10,30,100,300,1000"
  }
  USER_ACHIEVEMENT {
    bigint user_id PK_FK
    bigint achievement_id PK_FK
    int progress_count
    int achieved_tier
  }
  LIFEDEX_ENTRY {
    bigint user_id PK_FK
    string category PK
    int collected
    int total
  }
  TITLE {
    bigint id PK
    string code
    string name
    string unlock_condition
  }
  USER_TITLE {
    bigint user_id PK_FK
    bigint title_id PK_FK
    datetime unlocked_at
  }
  FRIENDSHIP {
    bigint id PK
    bigint user_id FK
    bigint friend_id FK
    string status "PENDING|ACCEPTED"
  }
  RANKING_SNAPSHOT {
    bigint id PK
    bigint user_id FK
    date week_start
    bigint weekly_exp
    int rank
  }
  REWARD_LOG {
    bigint id PK
    bigint user_id FK
    string source "LEVEL_UP|TREASURE_CHEST"
    string reward_type
    bigint reward_ref_id
    datetime granted_at
    string idempotency_key UK
  }
  INVENTORY {
    bigint id PK
    bigint user_id FK
    string item_type
    bigint item_ref_id
    datetime acquired_at
    boolean equipped
  }
```

## 테이블 요약 (담당별)

| 담당 | 테이블 |
|---|---|
| 팀원1 | `USER`, `QUEST`, `USER_QUEST` |
| 팀원2 | `LOCATION`, `REGION`, `QUEST_LOCATION` |
| 팀원3 | `ACHIEVEMENT`, `USER_ACHIEVEMENT`, `LIFEDEX_ENTRY`, `TITLE`, `USER_TITLE` |
| 팀원4 | `FRIENDSHIP`, `RANKING_SNAPSHOT`, `REWARD_LOG`, `INVENTORY` |

## 제약 조건 요약

- `USER.email` — UNIQUE
- `USER_QUEST` — `(user_id, quest_id, assigned_date)` UNIQUE (동일 유저에게 같은 날 동일 퀘스트 중복 배정 방지), `idempotency_key` UNIQUE (완료 요청 중복 방지 — [비즈니스 규칙서](./business-rules.md) §4)
- `USER_ACHIEVEMENT` — PK = `(user_id, achievement_id)`
- `LIFEDEX_ENTRY` — PK = `(user_id, category)`
- `USER_TITLE` — PK = `(user_id, title_id)`
- `FRIENDSHIP` — `(user_id, friend_id)` UNIQUE, `user_id ≠ friend_id`
- `REWARD_LOG.idempotency_key` — UNIQUE (레벨업/보물상자 중복 지급 방지)
- `QUEST_LOCATION.quest_id` — PK이자 FK (위치 퀘스트만 행이 존재, 1:0..1)
