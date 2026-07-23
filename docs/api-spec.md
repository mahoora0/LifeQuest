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
| `UNAUTHORIZED` | 401 | 토큰 없음/만료 |
| `FORBIDDEN` | 403 | 본인 리소스 아님 |
| `NOT_FOUND` | 404 | 대상 없음 |
| `VALIDATION_ERROR` | 400 | 요청 형식/값 오류 |
| `CONFLICT` | 409 | 상태 충돌(예: 이미 만료된 퀘스트 완료 시도) |
| `INTERNAL_ERROR` | 500 | 서버 오류 |

## 1. 인증 (담당: 팀원1)

| Method | Path | 설명 |
|---|---|---|
| POST | `/auth/signup` | 회원가입 |
| POST | `/auth/login` | 로그인, JWT 발급 |

**POST /auth/login**
```json
// Request
{ "email": "a@b.com", "password": "..." }
// Response 200
{ "data": { "accessToken": "...", "nickname": "홍길동", "level": 4 } }
```
오류: `VALIDATION_ERROR`(형식), `401 UNAUTHORIZED`(자격 불일치, code 재사용).

## 2. 퀘스트 (담당: 팀원1)

| Method | Path | 설명 |
|---|---|---|
| GET | `/quests/today` | 오늘의 배정 퀘스트 목록 |
| GET | `/quests/{userQuestId}` | 퀘스트 상세 |

**GET /quests/today**
```json
// Response 200
{ "data": [
  { "userQuestId": 101, "title": "새로운 카페 방문", "category": "카페",
    "tier": "일반", "expReward": 10, "status": "ASSIGNED",
    "locationRequired": false }
]}
```
빈 배열은 정상 응답(오류 아님) — [화면 명세서](./screen-spec.md) "빈 화면" 참조.

## 3. 위치 인증 (담당: 팀원2)

| Method | Path | 설명 |
|---|---|---|
| POST | `/quests/{userQuestId}/verify-location` | GPS 위치 인증 |

```json
// Request
{ "lat": 37.5665, "lng": 126.9780, "accuracy": 15, "timestamp": "2026-07-23T10:00:00Z" }
// Response 200 (성공)
{ "data": { "verified": true, "verifiedAt": "2026-07-23T10:00:03Z" } }
// Response 200 (실패 — 판정 결과지 오류 아님)
{ "data": { "verified": false, "reason": "OUT_OF_RADIUS" } }
```
`reason`: `OUT_OF_RADIUS` | `LOW_ACCURACY` | `STALE_TIMESTAMP` ([비즈니스 규칙서](./business-rules.md) §3).
`CONFLICT` — 이미 만료된 UserQuest에 인증 시도.

## 4. 퀘스트 완료 · 성장 (담당: 팀원1 · 팀원3)

| Method | Path | 설명 |
|---|---|---|
| POST | `/quests/{userQuestId}/complete` | 퀘스트 완료 — EXP/레벨/업적/도감/보상 일괄 처리 |
| GET | `/lifedex` | 도감 현황 |
| GET | `/achievements` | 업적 현황 |
| POST | `/titles/{titleId}/equip` | 대표 칭호 장착 |

**POST /quests/{userQuestId}/complete** — 멱등 (동일 요청 재전송 시 최초 결과 그대로 반환, [비즈니스 규칙서](./business-rules.md) §4)
```json
// Request
{ "idempotencyKey": "uq-101-complete" }
// Response 200
{ "data": {
  "expGained": 10,
  "levelUp": false,
  "newLevel": 4, "newExp": 340, "nextLevelExp": 700,
  "achievementsProgressed": [{ "code": "CAFE_EXPLORER", "progress": 11, "tierUp": false }],
  "lifedexUnlocked": ["카페:XX커피"],
  "chestReward": null
}}
```
오류: `CONFLICT`(만료된 퀘스트, 인증 필요한데 미인증) · `NOT_FOUND`.

**GET /lifedex**
```json
{ "data": [{ "category": "카페", "collected": 12, "total": 48 }] }
```

## 5. 친구 · 랭킹 · 보상 (담당: 팀원4)

| Method | Path | 설명 |
|---|---|---|
| GET | `/friends` | 친구 목록 |
| POST | `/friends/{userId}/request` | 친구 요청 |
| POST | `/friends/{userId}/accept` | 친구 요청 수락 |
| GET | `/ranking/weekly` | 주간 랭킹(친구 기준) |
| GET | `/users/me` | 내 프로필 |
| PATCH | `/users/me` | 프로필 수정 |

**GET /ranking/weekly**
```json
{ "data": { "weekStart": "2026-07-20", "entries": [
  { "userId": 1, "nickname": "홍길동", "weeklyExp": 2450, "rank": 1 }
]}}
```
친구가 없으면 `entries: []` — 오류 아님.

---

> 레벨업 보상·보물상자는 별도 API가 아니라 §4 완료 응답의 `levelUp`/`chestReward` 필드로 내려온다 — [화면 명세서](./screen-spec.md) "공통 규칙" 참조.
