# Life Quest — 화면 흐름도

로그인부터 퀘스트 완료까지 사용자 이동 경로. 화면별 상세는 [화면 명세서](./screen-spec.md), 규칙은 [비즈니스 규칙서](./business-rules.md) 참조.

```mermaid
%%{init: {'theme':'neutral'}}%%
flowchart TD
  Splash([앱 실행]) --> Auth{로그인 상태?}
  Auth -- 아니오 --> Login[로그인]
  Login -- 계정 없음 --> Signup[회원가입]
  Signup --> Login
  Auth -- 예 --> Home[홈 · 오늘의 퀘스트]

  Home --> Detail[퀘스트 상세]
  Detail --> LocQ{위치 기반 퀘스트?}
  LocQ -- 아니오 --> Complete[완료 요청]
  LocQ -- 예 --> Map[지도 · GPS 인증]
  Map -- 인증 성공 --> Complete
  Map -- 인증 실패 --> Map

  Complete --> Result[완료 결과<br/>EXP 획득]
  Result --> LevelUp{레벨업?}
  LevelUp -- 예 --> Reward[레벨업 보상 팝업]
  LevelUp -- 아니오 --> Chest{보물상자 등장?}
  Reward --> Chest
  Chest -- 예 --> ChestPopup[보물상자 팝업]
  Chest -- 아니오 --> Home
  ChestPopup --> Home

  Home --> MyPage[마이페이지]
  MyPage --> Dex[도감 · LifeDex]
  MyPage --> Achv[업적 · 칭호]
  MyPage --> Profile[프로필 편집]

  Home --> Social[친구 · 랭킹]
  Social --> FriendList[친구 목록]
  Social --> Ranking[주간 랭킹]
```

## 화면 목록 (담당)

| 화면 | 담당 | 비고 |
|---|---|---|
| 로그인 / 회원가입 | 팀원1 | |
| 홈 · 오늘의 퀘스트 | 팀원1 | |
| 퀘스트 상세 | 팀원1 | |
| 지도 · GPS 인증 | 팀원2 | 위치 퀘스트만 진입 |
| 완료 결과 / 레벨업 보상 / 보물상자 팝업 | 팀원3 · 팀원4 | 완료 API 응답 기반 |
| 도감(LifeDex) | 팀원3 | |
| 업적 · 칭호 | 팀원3 | |
| 프로필 | 팀원4 | |
| 친구 목록 · 랭킹 | 팀원4 | |
