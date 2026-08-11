# 10. 모션 개선 계획 (P0 ~ P3)

> 관련 문서: `09-design-system.md`(§3 애니메이션 · §2 컴포넌트) · `AGENTS.md`(CI)

앱의 모든 탭 대상이 `GestureDetector` 원형이고 `NoSplash` + `highlightColor: transparent`라
**누르는 순간 아무 반응이 없다.** 라우트 41개는 전부 Material 기본 전환이고 모션 상수는
여섯 파일에 흩어져 있다. 이 문서는 그 상태를 네 단계로 정리하는 계획과, 각 단계를 **무엇으로
증명할 것인지**를 고정한다.

계획을 세우기 전에 확인한 사실은 아래와 같다.

| 항목 | 확인값 |
|---|---|
| 툴체인 | `flutter`가 PATH에 없고 fvm 3.44.8만 설치됨. CI 고정 버전과 일치 |
| 기준선 테스트 | `flutter test` **206개 전부 통과, 8초** (착수 시점) |
| `pumpAndSettle()` | 123회 / 16개 파일. 그중 앱 전체를 마운트하는 것은 `app_smoke_test.dart`와 `integration_test/app_e2e_test.dart` 두 개뿐 |
| 골든 테스트 | 없음. **도입하지 않는다** — A2Z 폰트 렌더링 차이로 CI가 흔들린다 |

---

## 0. 이 앱에서는 scale이 아니라 "스티커 눌림"이다

일반적인 조언은 누를 때 `AnimatedScale 0.975`를 권한다. 그러나 LifeQuest의 표면은
blur 없는 오프셋 섀도(`Offset(3,4)` · `Offset(4,5)`)를 쓰는 **종이 스티커** 언어다.
여기서는 그림자가 줄고 그만큼 위젯이 그 자리로 내려가는 쪽이 정체성에 맞고 물리적으로도 옳다.

```
평상시  shadow Offset(3,4) · translate(0,0)
눌림    shadow Offset(1,1) · translate(2,3)   ← 스티커가 종이에 눌러 붙는다
```

scale은 쓰지 않는다. 이 규칙이 P0의 전부이며, 아래 모든 단계가 이 톤 위에 쌓인다.

## 0-1. 패키지를 늘리지 않는다

| 후보 | 판단 | 이유 |
|---|---|---|
| `animations` | 미도입 | `OpenContainer`·`SharedAxis`는 M3 룩앤필이 강해 손그림 톤과 충돌한다. 필요한 fade-through는 직접 20줄 |
| `flutter_animate` | 미도입 | stagger 하나 때문에 의존성을 늘릴 이유가 없다 |
| Rive · Lottie | 미도입 | 룩이 SVG stroke 2.2 + 캐릭터 PNG로 확정돼 있다. 에셋 제작자가 없으면 톤이 반드시 어긋나고 `assets/images/characters/`와 이중 관리가 된다 |

즉 **Flutter 기본 API만 쓰고 `pubspec.yaml`은 건드리지 않는다.**

---

## 공통 규칙

**단계별 1 PR.** 브랜치 `feature/memberN-motion-p0` … `-p3`. 합치면 회귀 원인을 분리할 수 없다.

모든 PR이 통과해야 하는 게이트(CI와 동일):

```bash
cd app && dart format lib test && fvm flutter analyze && fvm flutter test
```

**모션 테스트 3원칙** — 지키지 않으면 테스트가 시간에 의존해 흔들린다.

1. 중간 상태는 `pumpAndSettle()`이 아니라 `pump(Duration(...))`으로 프레임을 직접 밟아 본다.
2. "부드러워 보이는지"는 테스트하지 않는다. 검증 대상은 **duration 값 · 위젯 트리 존재 · 최종 상태** 셋뿐이다.
3. 무한 애니메이션이 있는 화면에서 `pumpAndSettle()`을 쓰지 않는다(`LqSpeck` 규칙, 09 문서 §2).

---

## P0 — 모션 토큰 + 프레스 피드백

### 변경

| 파일 | 내용 |
|---|---|
| `lq_tokens.dart` | `LqMotion` 추가 |
| `shared/widgets/lq_pressable.dart` | 신규. 눌림 상태만 제공하는 builder |
| `lq_button.dart` · `lq_card.dart` · `lq_bottom_nav.dart` · `lq_chip.dart` | 적용 |

`LqPressable`은 그림자를 대신 그리지 않는다. 위젯마다 그림자 값이 다르므로 **상태(bool)만 넘기고
그림자·오프셋은 각 위젯이 자기 값으로 보간**한다. `onTap`이 null이면 프레스 상태로 진입하지 않는다.

### 검증

신규 `test/shared/lq_pressable_test.dart`

| 케이스 | 방법 |
|---|---|
| 누르면 시각 상태가 바뀐다 | `startGesture` → `pump(LqMotion.press)` → 대상 값이 초기값과 다름 |
| 떼면 원상복구 | `up()` → `pump(LqMotion.press)` → 초기값과 동일 |
| 드래그로 이탈하면 취소 | `moveBy(0,60)` → `up()` → 원상복구 + `onTap` **미호출** |
| 비활성은 눌리지 않는다 | `onPressed: null`에서 값 불변 |
| 탭 콜백 회귀 | `onTap`이 정확히 1회 호출된다 |

회귀: 전체 테스트가 기준선(206)과 동일. 특히 `entry_points_test.dart`는 "눌러도 아무 일이 없으면
고장"을 지키는 테스트라 탭 구조 변경에 민감하다 — **`tester.tap()`이 계속 동작하는 것이 통과 조건.**

수동(실기기): 목록을 빠르게 스크롤할 때 카드가 눌린 채 남지 않음 · 탭 연타 시 잔상 없음 ·
비활성 버튼 무반응 · 눌림 폭이 과하지 않음.

**롤백** — 사용처를 `GestureDetector`로 되돌리면 끝. 토큰은 남아도 무해하다.

---

## P1 — 페이지 전환 통일 (가장 위험한 단계)

### 변경

| 파일 | 내용 |
|---|---|
| `app/router/lq_page.dart` | 신규. `CustomTransitionPage` 래퍼 `lqPage()` |
| `app_router.dart` | 탭 밖 push 라우트를 `builder:` → `pageBuilder:` |

fade + `Offset(0, 0.02)`, forward 280ms / reverse 220ms. 라우트를 한 줄 패턴
`pageBuilder: (c, s) => lqPage(s, XScreen())`으로 통일한다.

`/splash` · `/login` · `/signup`은 **제외**한다. 리다이렉트로 자동 전환되는 경로에 슬라이드를 넣으면
앱 시작이 굼떠 보인다.

탭 전환(fade-through)은 `IndexedStack`의 브랜치 상태 보존을 깨면 안 되므로 `navigationShell`
전체를 `AnimatedSwitcher`로 감싸지 않는다. 구현이 지저분해지면 **이 항목만 드롭해도 P1은 성립**한다.

### 검증

신규 `test/app/route_transition_test.dart`

| 케이스 | 방법 |
|---|---|
| push 라우트가 커스텀 전환을 쓴다 | `CustomTransitionPage`이고 `transitionDuration == LqMotion.page` |
| 전환 중 두 화면이 공존 | `pump()` → `pump(140ms)`에서 이전·다음 화면 동시 존재 → settle 후 이전 화면 사라짐 |
| 뒤로가기가 더 빠르다 | `pageReverse < page` |
| 인증 라우트는 전환 없음 | `/login`이 `CustomTransitionPage`가 **아님** |
| 탭 상태 보존 | 탭 이동 후 복귀 시 상태 유지 |

회귀가 이 단계의 핵심이다. `pumpAndSettle()`은 애니메이션 종료까지 기다리므로 대부분 그냥 통과한다.
깨진다면 원인은 둘 중 하나다.

- **(a)** 전환 중 위젯이 두 벌 존재해 `findsOneWidget`이 2개가 됨 → assert를 `pumpAndSettle()` 뒤로 옮긴다.
- **(b)** 무한 애니메이션 화면으로 전환해 타임아웃 → **P3-a를 앞당겨 해결**한다.

통합 테스트도 반드시 돌린다: `fvm flutter test integration_test/app_e2e_test.dart -d <device>`

수동: 시스템 뒤로 제스처로 pop 시 전환이 깨지지 않음 · 전환 중 연타로 이중 push 없음 ·
`/quests/result` → 뒤로 → 목록 복귀 시 화면이 튀지 않음.

성능: 실기기 profile mode에서 전환 반복 시 raster 16ms 초과 프레임이 기준선 대비 증가하지 않을 것.

**롤백** — `lqPage`를 `MaterialPage` 반환으로 바꾸는 **1줄 수정**으로 전체를 되돌릴 수 있어야 한다.
이 롤백 경로를 확보하는 것이 P1 설계의 필수 조건이다.

---

## P2 — 연결감

커밋은 셋으로 나누되 PR은 하나로 간다.

### P2-a. Hero

`shared/design/lq_hero_tags.dart` 신규로 tag 생성을 중앙화한다. **중복 tag는 런타임 크래시**이며,
같은 화면에 같은 아바타가 두 번 나오는 상황(친구 목록 + 검색 결과)이 실제로 존재한다.

| 케이스 | 방법 |
|---|---|
| 같은 tag가 화면에 하나뿐 | `find.byType(Hero)`의 tag를 모아 중복 없음 assert — 크래시를 테스트로 선점한다 |
| 전환 중 Hero가 뜬다 | push 후 `pump(100ms)`에 `Hero` 존재 |
| tag 규칙 순수성 | `LqHeroTags.avatar(3) != LqHeroTags.quest(3)` |

### P2-b. AnimatedSwitcher

레벨/EXP 숫자 · 알림 뱃지 카운트 · 완료 체크. fade + scale 0.97→1, `LqMotion.normal`.
각 child에 **`ValueKey(값)` 필수** — 없으면 애니메이션이 뜨지 않는다.

| 케이스 | 방법 |
|---|---|
| 값 변경 시 두 값이 잠시 공존 | `pump()` → `pump(110ms)`에서 옛 값·새 값 동시 존재 → settle 후 새 값만 |
| key가 값에 묶여 있다 | child key가 `ValueKey(count)` |
| 기존 텍스트 단언 회귀 | settle 후 `findsOneWidget` 유지 |

### P2-c. Stagger

홈·목록의 **첫 6개까지만** fade + y 10px, 40ms 간격, 총 200ms 이내. 패키지 없이 index 기반
`TweenAnimationBuilder`. **재빌드마다 재생되면 안 된다** — 스크롤·상태 갱신 때 다시 날아오면 최악이다.

| 케이스 | 방법 |
|---|---|
| 총 시간 상한 | 마지막 delay + duration ≤ 300ms를 상수 테스트로 고정 |
| 재빌드 시 재생 안 함 | settle 후 `setState` 유발 → 1프레임 시점에 opacity 1 유지 |
| 7번째 이후 지연 없음 | index ≥ 6이면 delay == 0 |

---

## P3 — 접근성 + 클라이맥스

### P3-a. Reduce Motion (어느 단계에서 멈추든 반드시 포함)

`LqMotion.of(context)`가 `MediaQuery.disableAnimations`를 보고 모든 duration을 `Duration.zero`로
바꾼다. `LqSpeck` · `LqPulseRing` · 결과 화면 `_FloatingPiece`는 **`repeat()`을 아예 시작하지 않는다.**

| 케이스 | 방법 |
|---|---|
| 무한 애니메이션이 멈춘다 | `disableAnimations: true`로 감싸고 **`pumpAndSettle()`이 타임아웃 없이 완료**됨을 assert — 현재는 반드시 타임아웃하므로 이 테스트 자체가 증거다 |
| 평소엔 계속 돈다 | 기본 MediaQuery에서 `pump(1s)` 후 프레임이 계속 예약됨 |
| duration이 0이 된다 | `LqMotion.of` 단위 테스트 |
| 전환도 즉시 | reduce motion에서 push 후 `pump()` 한 번에 새 화면 도착 |

수동은 **실기기**에서 한다(에뮬레이터 아님). iOS 손쉬운 사용 → 동작 → 동작 줄이기 ON,
Android 개발자 옵션 → 애니메이션 배율 off. 앱 전체를 한 바퀴 돌며 멈춤·깨짐 없음 확인.

이 단계는 접근성뿐 아니라 **기존 테스트 부채**(무한 애니메이션 화면에서 `pumpAndSettle()`을 못 쓰는 문제)를
같이 갚는다.

### P3-b. 클라이맥스 한 곳

`quest_result_screen.dart`에만 `LqMotion.emphasized` + `LqMotion.bounce`를 허용한다.
**앱 전체에서 바운스가 허용되는 유일한 화면**이며 코드 주석과 09 문서에 그렇게 적는다.
검증: 기존 `quest_result_screen_test.dart` 회귀 + "완료 연출 총 길이 ≤ 900ms" 상수 테스트.

### P3-c. 문서 개정 (코드와 같은 PR)

`09-design-system.md` §3의 **"그 외 전환은 넣지 않는다"를 개정**하고 아래를 명문화한다.
이 개정이 없으면 다음 기여자가 규칙 위반으로 판단해 되돌린다.

- 모션 토큰 표
- 프레스 피드백은 scale이 아니라 섀도 오프셋 감소 + translate
- 바운스는 퀘스트 완료 결과 화면 전용
- Reduce Motion 대응은 신규 애니메이션의 필수 요건
- 패키지 미도입 결정과 이유

---

## 리스크

| 리스크 | 단계 | 완화 |
|---|---|---|
| 123개 `pumpAndSettle()` 회귀 | P1 | 기준선 206 + `lqPage` 1줄 롤백 |
| Hero 중복 tag 크래시 | P2-a | tag 중앙화 + 중복 검사 테스트 |
| 무한 애니메이션 × 전환 → 타임아웃 | P1 → P3 | P3-a가 근본 해결. P1에서 터지면 앞당긴다 |
| 스크롤 중 프레스 오발동 | P0 | `onTapCancel` 검증 테스트 |
| 저사양 기기 프레임 저하 | 전 단계 | profile mode 기준선 대비 비교 |
| 문서와 코드 불일치 | 전 단계 | P3-c를 마지막 PR에 필수 포함 |

## 중단 가능 지점

P0만 해도 체감의 절반을 가져간다. P1까지가 완성도 라인, P2는 취향이다.
**P3-a는 어디서 멈추든 반드시 포함한다.**
