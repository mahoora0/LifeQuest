# 캐릭터 · 아이콘 이미지

디자인 프로젝트(`Life Quest 초안`)의 `assets/`에 있는 PNG 9종을 이 디렉터리에 그대로 둔다.
파일명은 바꾸지 않는다 — `lib/shared/design/lq_assets.dart`가 이 이름으로 참조한다.

| 파일 | 쓰이는 곳 |
|---|---|
| `logo-char.png` | 홈 상단 로고 |
| `char-wave.png` | 홈 인사말 |
| `char-sit.png` | 퀘스트 상세(직접 완료) · 빈 상태 · 오류 상태 |
| `char-walk.png` | 완료 결과 · 로딩 상태 |
| `char-map.png` | 퀘스트 상세(위치) · LifeDex 안내 · 인증 성공 모달 |
| `char-front.png` | 지도 현재 위치 · 프로필 기본 아바타 · GPS 레이더 내 위치 |
| `icon-flag.png` | GPS 레이더 중앙 목표 지점 |
| `icon-map.png` | 지도 관련 아이콘 |
| `icon-backpack.png` | LifeDex 타이틀 · 신규 수집 안내 |

## 파일이 아직 없어도 앱은 동작한다

모든 사용처는 `LqImage`를 거치며, 자산 로딩에 실패하면 같은 크기의 블롭 도형으로
폴백하도록 되어 있다. 실제 PNG를 넣으면 별도 코드 변경 없이 바로 반영된다.
