# Life Quest — API 명세서

프론트·백엔드 공통 계약. 화면별 사용처는 [화면 명세서](./screen-spec.md), 값 계산 규칙은 [비즈니스 규칙서](./business-rules.md) 참조.

## 0. 공통 규약

- Base URL: `/api/v1`
- 인증: `Authorization: Bearer {JWT}` (로그인/회원가입 제외 전 API)
- 요청/응답: JSON, 날짜는 ISO-8601
- 성공 응답: `{ "data": ... }`
- 오류 응답: `{ "error": { "code": "...", "message": "..." } }`

### 공통 오류 코드

| code | HTTP | 의미 |
|---|---|---|
| `UNAUTHORIZED` | 401 | 토큰 없음/만료, 자격 불일치 |
| `FORBIDDEN` | 403 | 본인 리소스 아님 |
| `NOT_FOUND` | 404 | 대상 없음 |
| `VALIDATION_ERROR` | 400 | 요청 형식/값 오류 |
| `CONFLICT` | 409 | 상태 충돌(예: 만료된 퀘스트 완료 시도, 이메일 중복) |
| `INTERNAL_ERROR` | 500 | 서버 오류 |

## 1. 인증 (담당: 팀원1)

| Method | Path | 설명 |
|---|---|---|
| POST | `/auth/signup` | 회원가입 |
| POST | `/auth/login` | 로그인, JWT 발급 |

**POST /auth/signup**
```json
// Request
{ "email": "a@b.com", "password": "...", "nickname": "홍길동" }
// Response 201
{ "data": { "userId": 1, "nickname": "홍길동" } }
```
오류: `VALIDATION_ERROR`(형식·비밀번호 정책), `CONFLICT`(이메일/닉네임 중복).

**POST /auth/login**
```json
// Request
{ "email": "a@b.com", "password": "..." }
// Response 200
{ "data": { "accessToken": "...", "nickname": "홍길동", "level": 4 } }
```
오류: `VALIDATION_ERROR`(형식), `UNAUTHORIZED`(자격 불일치).

## 2. 퀘스트 (담당: 팀원1 · 팀원2)

| Method | Path | 설명 |
|---|---|---|
| GET | `/quests/today` | 오늘의 배정 퀘스트 목록 |
| GET | `/quests/{userQuestId}` | 퀘스트 상세 |

**GET /quests/today**
```json
// Response 200
{ "data": [
  { "userQuestId": 101, "title": "새로운 카페 방문", "category": "카페",
    "tier": "COMMON", "expReward": 10, "status": "ASSIGNED" }
]}
```
빈 배열은 정상 응답(오류 아님) — [화면 명세서](./screen-spec.md) "빈 화면" 참조. `tier`: `COMMON` | `RARE` | `EPIC` | `LEGENDARY`.

## 3. 퀘스트 완료 (담당: 팀원2)

| Method | Path | 설명 |
|---|---|---|
| POST | `/quests/{userQuestId}/complete` | 퀘스트 완료 — EXP/레벨/보상/업적/도감 일괄 처리 |

**멱등** — 동일 `idempotencyKey` 재전송 시 최초 결과 그대로 반환([비즈니스 규칙서](./business-rules.md) §3).
```json
// Request
{ "idempotencyKey": "uq-101-complete" }
// Response 200
{ "data": {
  "expGained": 10,
  "levelUp": false,
  "newLevel": 4, "newExp": 340, "nextLevelExp": 700,
  "levelRewards": [],
  "achievementsProgressed": [{ "code": "CAFE_EXPLORER", "progress": 11, "tierUp": false, "newTier": 1 }],
  "lifedexUnlocked": [{ "category": "카페", "name": "새로운 카페" }],
  "unlockedTitles": [],
  "chestReward": null
}}
```
- `levelUp: true`이면 `levelRewards`에 지급 보상 목록(`[{ "rewardType": "BORDER", "name": "청동 테두리" }]`)이 포함된다.
- `chestReward`는 **Phase 2 예약 필드**로 MVP에서는 항상 `null`이다([비즈니스 규칙서](./business-rules.md) §11).
- 오류: `CONFLICT`(만료된 퀘스트) · `FORBIDDEN`(타인 퀘스트) · `NOT_FOUND`.

## 4. 도감 · 업적 · 칭호 (담당: 팀원3)

| Method | Path | 설명 |
|---|---|---|
| GET | `/lifedex` | 카테고리별 수집 현황 요약 |
| GET | `/lifedex/{category}` | 카테고리 내 항목별 수집 여부 |
| GET | `/achievements` | 업적 진행 현황 |
| GET | `/titles` | 보유/미보유 칭호 목록 |
| POST | `/titles/{titleId}/equip` | 대표 칭호 장착 |
| DELETE | `/titles/equip` | 대표 칭호 해제 |

**GET /lifedex**
```json
{ "data": { "totalCollected": 23, "totalItems": 120, "categories": [
  { "category": "카페", "collected": 12, "total": 48 }
]}}
```

**GET /lifedex/{category}**
```json
{ "data": [
  { "itemId": 7, "name": "초밥", "collected": true, "collectedAt": "2026-07-01T12:00:00Z" },
  { "itemId": 8, "name": "태국 음식", "collected": false, "collectedAt": null }
]}
```

**GET /achievements**
```json
{ "data": [
  { "code": "CAFE_EXPLORER", "name": "카페 탐험가", "progress": 11,
    "achievedTier": 1, "nextThreshold": 30, "maxTier": 5 }
]}
```

**POST /titles/{titleId}/equip** — 오류: `FORBIDDEN`(미보유 칭호), `NOT_FOUND`.

## 5. 친구 · 랭킹 (담당: 팀원4)

| Method | Path | 설명 |
|---|---|---|
| GET | `/friends` | 친구 목록(수락됨) + 받은/보낸 요청 |
| POST | `/friends/{userId}/request` | 친구 요청 |
| POST | `/friends/{userId}/accept` | 친구 요청 수락 |
| POST | `/friends/{userId}/reject` | 친구 요청 거절 |
| GET | `/friends/{userId}/profile` | 친구 프로필(레벨·EXP·대표 업적 비교) |
| GET | `/ranking/weekly` | 주간 랭킹(나 + 친구) |

**POST /friends/{userId}/request** — 오류: `CONFLICT`(이미 친구/요청 중, 자기 자신), `NOT_FOUND`.

**GET /ranking/weekly**
```json
{ "data": { "weekStart": "2026-07-20", "entries": [
  { "userId": 1, "nickname": "홍길동", "level": 12, "weeklyExp": 2450, "rank": 1, "isMe": false }
]}}
```
친구가 없으면 내 항목만 내려온다(`entries` 길이 1) — 오류 아님.

## 6. 마이페이지 (담당: 팀원4)

| Method | Path | 설명 |
|---|---|---|
| GET | `/users/me` | 내 프로필(레벨·EXP·칭호·장착 아이템) |
| PATCH | `/users/me` | 닉네임 · 대표 업적 수정 |
| GET | `/users/me/inventory` | 보유 꾸미기 아이템 목록 |
| POST | `/inventory/{inventoryId}/equip` | 아이템 장착(같은 슬롯 기존 장착은 자동 해제) |
| POST | `/inventory/{inventoryId}/unequip` | 아이템 해제 |

**GET /users/me**
```json
{ "data": {
  "userId": 1, "email": "a@b.com", "nickname": "홍길동",
  "level": 12, "levelName": "탐험가", "exp": 5300, "nextLevelExp": 6100,
  "equippedTitle": { "titleId": 3, "name": "카페 마스터" },
  "featuredAchievement": { "code": "CAFE_EXPLORER", "achievedTier": 3 },
  "equipped": { "border": "청동 테두리", "background": null, "badge": null }
}}
```

---

> 레벨업 보상 팝업은 별도 API가 아니라 §3 완료 응답의 `levelUp`/`levelRewards` 필드로 렌더한다 — [화면 명세서](./screen-spec.md) "공통 규칙" 참조. Phase 2(보물상자·지역·시즌·스토리) API는 이 문서에 없음.
