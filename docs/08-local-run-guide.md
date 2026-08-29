# 08. 로컬 실행 가이드

이 문서는 Windows와 macOS에서 Spring Boot 백엔드와 Flutter Android/iOS 앱을
실행하는 절차를 설명한다. 저장소는 어느 경로에 두어도 되며, SDK와 캐시 경로도
PC마다 달라도 된다. PC별 설정 원본은 Git에 커밋하지 않는 루트 `.env`이다.

## 1. 공통 준비

- Git
- Java 17
- Flutter 3.44.8
- Docker Desktop/Engine + Compose 또는 로컬 MySQL 8.x
- Android 빌드: Android Studio와 Android SDK Platform-Tools
- iOS 빌드: macOS, Xcode, CocoaPods

확인:

```bash
git --version
java -version
flutter --version
flutter doctor -v
```

Flutter 버전은 루트 `.fvmrc`에 3.44.8로 고정되어 있다. FVM을 사용하는 경우
저장소 루트에서 다음과 같이 맞출 수 있다.

```bash
fvm install
fvm use
```

FVM은 필수가 아니다. PATH에서 실행되는 `flutter`와 `dart`가 Flutter 3.44.8에
포함된 것이면 된다. 공통 실행기는 버전이 다르면 실행 전에 안내하고 종료한다.

macOS에서 iOS 앱을 실행하려면 Xcode의 최초 설정과 라이선스 동의, CocoaPods
설치를 먼저 마친다. Apple Silicon에서 요구되는 추가 항목을 포함한 상태는
`flutter doctor -v`로 확인한다.

## 2. 최초 설정

저장소 루트에서 `.env`를 만든다.

```powershell
# Windows PowerShell
Copy-Item .env.example .env
```

```bash
# macOS
cp .env.example .env
```

`.env`에서 최소한 다음 값을 현재 PC 환경에 맞게 설정한다.

```dotenv
DB_URL=jdbc:mysql://localhost:3306/lifequest?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Seoul
DB_USERNAME=lifequest
DB_PASSWORD=로컬_MYSQL_비밀번호
JWT_SECRET=최소_32자_이상의_임의_문자열
GOOGLE_CLIENT_ID=숫자-문자열.apps.googleusercontent.com
```

`GOOGLE_CLIENT_ID`에는 Android/iOS 클라이언트 ID가 아니라 서버에서 ID Token의
audience를 검증할 때 사용하는 Google 웹 애플리케이션 클라이언트 ID를 넣는다.
OAuth `client_secret`은 백엔드나 Flutter 앱에 넣지 않는다.

패키지를 내려받는다.

```bash
cd app
flutter pub get
cd ..
```

`flutter pub get`이 각 PC의 Flutter SDK, Pub 캐시 및 프로젝트 절대 경로를
로컬 생성 파일에 기록한다. 이 파일들은 `.gitignore`로 제외되어 있으므로 서로
복사하거나 커밋하지 않는다.

## 3. MySQL 실행

### Docker MySQL

저장소 루트에서 실행한다.

```bash
docker compose up -d
docker compose ps
```

`lifequest-mysql` 상태가 healthy이면 사용할 수 있다. 컨테이너의 DB 이름,
사용자와 비밀번호는 `.env`의 `MYSQL_*` 값으로 생성된다.

MySQL 볼륨을 만든 뒤 `.env`의 비밀번호만 변경해도 기존 DB 사용자 비밀번호는
자동으로 변경되지 않는다. 중지는 다음 명령을 사용한다.

```bash
docker compose stop
```

### PC에 설치된 MySQL

MySQL 관리자 계정으로 다음 데이터베이스와 사용자를 준비한다.

```sql
CREATE DATABASE IF NOT EXISTS lifequest
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

CREATE USER IF NOT EXISTS 'lifequest'@'localhost'
  IDENTIFIED BY '로컬_MYSQL_비밀번호';

ALTER USER 'lifequest'@'localhost'
  IDENTIFIED BY '로컬_MYSQL_비밀번호';

GRANT ALL PRIVILEGES ON lifequest.* TO 'lifequest'@'localhost';
FLUSH PRIVILEGES;
```

SQL의 비밀번호와 `.env`의 `DB_PASSWORD`가 같아야 한다.

## 4. Spring Boot 실행

VS Code에서는 저장소 루트를 연 뒤 Java 프로젝트 가져오기가 끝날 때까지 기다린다.
이후 `Run and Debug` 목록에서 `LifeQuest Backend`를 선택하고 F5 또는 ▶ 버튼을
누르면 된다. 공유 설정 `.vscode/launch.json`에 메인 클래스와 작업 디렉터리가
지정되어 있으므로 `LifeQuestApiApplication.java`를 직접 열거나 한 번 먼저
실행할 필요가 없다.

Windows:

```powershell
cd backend
.\gradlew.bat bootRun
```

macOS:

```bash
cd backend
./gradlew bootRun
```

Spring Boot는 `backend`에서 실행하면 `../.env`, 저장소 루트 또는 IDE에서
실행하면 `./.env`를 읽는다. OS 환경 변수와 명령행 인자가 `.env`보다 우선한다.
Flyway는 시작 시 DB 스키마를 자동 적용한다.
업로드한 프로필 사진은 기본적으로 백엔드 실행 디렉터리의 `uploads/profile`에
저장된다. 포트폴리오 로컬 실행을 위한 저장 방식이며 이 디렉터리는 Git에서 제외된다.

확인:

```bash
curl http://localhost:8080/actuator/health
curl http://localhost:8080/api/system/ping
```

PowerShell에서는 `Invoke-RestMethod`를 사용해도 된다.

### 시연용 더미 데이터

빈 DB로 앱을 실행하면 친구·그룹·인증 게시물·알림 화면이 모두 비어 있어 대부분의 흐름을
눌러 볼 수 없다. `demo` 프로파일을 켜면 시연용 사용자 12명과 그 관계가 한 번 적재된다.

```powershell
# Windows
cd backend
.\gradlew.bat bootRun "--args=--spring.profiles.active=demo"
```

```bash
# macOS
cd backend
./gradlew bootRun --args='--spring.profiles.active=demo'
```

적재되는 것은 다음과 같다. 각 항목은 화면 분기를 눌러 볼 수 있도록 **상태를 섞어** 넣는다.

| 대상 | 들어가는 상태 |
| --- | --- |
| 사용자 12명 | 레벨 1~22. 가입 직후(활동 0) 계정도 하나 포함 |
| 친구 | 친구 4명 · 받은 요청 2건 · 보낸 요청 1건 · 거절된 요청 1건 |
| 그룹 6개 | 주인공이 만든 곳 · 참여 중 · 초대받음 · 가입 신청 중 · 미참여 공개 · 비공개 |
| 그룹 멤버 | 활동 중 · 승인 대기 · 초대 대기 · 탈퇴 |
| 그룹 퀘스트 | 예정(참가 신청함/안 함) · 완료(보상 지급됨) · 취소 |
| 그룹 채팅 | 두 그룹에 여러 사람이 주고받은 대화 |
| 퀘스트 이력 | 위치 인증·직접 완료 12건, 오늘 진행 중 1건 |
| 인증 게시물 | 투표 중 · 검증됨 · 애매함, 투표·댓글 포함 |
| 알림 | 읽음·안읽음 혼재 |
| 도감·칭호 | 일부만 수집(전부 채우면 "수집 중" 상태가 사라진다) |

로그인 계정은 `demo@lifequest.test`, 비밀번호는 `demo1234!`이다. 열두 명 모두 같은 비밀번호를
쓰므로 다른 사람 화면도 로그인해서 볼 수 있다. 모든 관계는 주인공을 중심으로 짜여 있다.

프로파일을 켜지 않으면 아무것도 적재되지 않고, 이미 적재된 DB에서 다시 켜도 중복으로 쌓이지
않는다.

> [!warning] 이 데이터를 막는 것은 프로파일 하나뿐이다
> `demo`를 켜면 대상이 어디든 시연용 가짜 사용자가 들어간다. **운영 DB에 켜지 않도록 확인하는
> 책임은 실행하는 사람에게 있다.** 적재 직전 경고 로그에 그 DB의 기존 사용자 수가 찍히므로,
> 예상과 다르면 즉시 멈춘다.

### 시연 데이터 회수

**사용자 한 명을 지우는 것으로는 안 된다.** `users.id`를 외래 키로 참조하는 테이블이 스물한 개이고
`user_achievements` 하나를 빼면 `ON DELETE CASCADE`가 없다(스키마 전체 외래 키 52개 중 `CASCADE`는
그 하나뿐이다). 여기에 외래 키 없이 `user_id`만 가진 표 넷과 게시물의 자식 표 하나를 더해
**스물여섯 개**를 아래 순서로 지운다.

자식 행은 **사용자 기준과 부모 기준 둘 다로** 지운다. 시연 사용자의 게시물이나 그룹에 시연이
아닌 사용자가 남긴 행(투표·댓글·채팅·멤버십·그룹 퀘스트 참가)은 사용자 기준으로만 지울 때
남고, 그러면 그 부모를 지우는 다음 `DELETE`가 외래 키 위반으로 실패한다.

#### 실행 방법

**회수 전에 백엔드를 멈춘다.** 시더는 부팅할 때 한 번만 돌므로 재적재하려면 어차피 재기동이
필요하고, 앱이 뜬 채로 사용자 행을 지우면 살아 있는 세션이 임의 오류를 낸다.

아래 블록은 하나의 트랜잭션이다. **터미널에 붙여 넣지 말고 파일로 저장해 한 번에 실행한다.**
붙여 넣으면 클라이언트가 오류 뒤에도 다음 문장을 계속 읽어 마지막 `COMMIT`까지 실행하므로,
절반만 지워진 상태가 그대로 커밋된다. 파일로 실행하면 첫 오류에서 멈추고 `COMMIT`에 닿지
못한 채 연결이 끊겨 서버가 되돌린다.

블록을 `recover-demo.sql`로 저장한 뒤 저장소 루트에서 실행한다. 비밀번호는 `.env`의
`DB_PASSWORD`다. `-T`가 있어야 표준 입력이 전달되고, 그 때문에 비밀번호를 물어볼 수 없으므로
`-p` 뒤에 붙여 쓴다.

```powershell
# Windows PowerShell — PS 5.1에는 입력 리다이렉션(<)이 없으므로 파이프로 넣는다
Get-Content -Encoding UTF8 recover-demo.sql | docker compose exec -T mysql mysql -ulifequest -p비밀번호 lifequest
```

```bash
# macOS
docker compose exec -T mysql mysql -ulifequest -p비밀번호 lifequest < recover-demo.sql
```

오류가 났을 때 할 일은 **`COMMIT`이 실행됐는지**로 갈린다.

| 상황 | 실제 상태 | 할 일 |
| --- | --- | --- |
| 파일 실행이 오류를 뱉고 프롬프트로 돌아왔다 | `COMMIT`에 닿지 못해 서버가 이미 되돌렸다 | 아무것도 지워지지 않았다. 원인을 고치고 다시 실행 |
| 세션이 열려 있고 `COMMIT`을 아직 치지 않았다 | 트랜잭션이 열려 있다 | `ROLLBACK;` |
| `COMMIT`이 이미 실행됐다 | **되돌릴 수 없다** | 블록 끝의 확인 질의로 남은 시연 사용자를 세고, 마저 지운 뒤 재적재 |

#### 회수 SQL

```sql
-- 파일로 저장해 한 번에 실행한다. 터미널에 붙여 넣으면 오류가 나도 클라이언트가 계속 읽어
-- 아래 COMMIT까지 실행되고, 절반만 지워진 상태가 그대로 커밋된다.
START TRANSACTION;

-- @demo는 세션 변수다. 이 블록의 일부만 잘라 새 세션에서 돌리면 email LIKE NULL이 되어
-- 오류 없이 0행만 지워지고, 그대로 재적재하면 시더가 "이미 있다"고 보고 건너뛴다.
SET @demo := '%@lifequest.test';

DELETE FROM quest_proof_votes
       WHERE voter_user_id IN (SELECT id FROM users WHERE email LIKE @demo)
          OR post_id IN (SELECT id FROM quest_proof_posts
                         WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo));
DELETE FROM quest_proof_comments
       WHERE author_user_id IN (SELECT id FROM users WHERE email LIKE @demo)
          OR post_id IN (SELECT id FROM quest_proof_posts
                         WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo));
DELETE FROM quest_proof_photos   WHERE post_id IN (SELECT id FROM quest_proof_posts
                                  WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo));
DELETE FROM quest_proof_posts    WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM quest_completions    WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM user_daily_quests    WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM quest_assignment_markers WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM weekly_ai_quest_claims   WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM quest_recommendation_candidates  WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM quest_recommendation_daily_usage WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM group_quest_participants
       WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo)
          OR group_quest_id IN (SELECT id FROM group_quests
                                WHERE group_id IN (SELECT id FROM quest_groups
                                      WHERE owner_user_id IN (SELECT id FROM users WHERE email LIKE @demo))
                                   OR created_by_user_id IN (SELECT id FROM users WHERE email LIKE @demo));
DELETE FROM group_quests         WHERE group_id IN (SELECT id FROM quest_groups
                                  WHERE owner_user_id IN (SELECT id FROM users WHERE email LIKE @demo))
                                    OR created_by_user_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM group_chat_messages
       WHERE sender_user_id IN (SELECT id FROM users WHERE email LIKE @demo)
          OR group_id IN (SELECT id FROM quest_groups
                          WHERE owner_user_id IN (SELECT id FROM users WHERE email LIKE @demo));
-- 초대자는 관계의 당사자가 아니다. 시연 사용자가 초대했다는 이유만으로 남의 그룹에 있는
-- 남의 멤버십까지 지우지 않도록, 그 열은 지우는 대신 참조만 끊는다.
UPDATE group_members SET invited_by_user_id = NULL
       WHERE invited_by_user_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM group_members
       WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo)
          OR group_id IN (SELECT id FROM quest_groups
                          WHERE owner_user_id IN (SELECT id FROM users WHERE email LIKE @demo));
DELETE FROM quest_groups         WHERE owner_user_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM friendships          WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo)
                                    OR friend_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM friend_requests      WHERE sender_id IN (SELECT id FROM users WHERE email LIKE @demo)
                                    OR receiver_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM notifications        WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM user_lifedex         WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM user_titles          WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM user_profile_items   WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM user_character_accessories WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM user_achievements    WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM exp_logs             WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM refresh_tokens       WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM social_accounts      WHERE user_id IN (SELECT id FROM users WHERE email LIKE @demo);
DELETE FROM users                WHERE email LIKE @demo;

-- 여기까지 오류가 한 줄도 없었는지 확인한 뒤에만 COMMIT한다.
COMMIT;

-- 회수 확인. 0이 아니면 끝나지 않은 것이다. 이 상태로 demo 프로파일을 켜면 시더가 건너뛰어
-- 로그인은 되는데 모든 화면이 빈 앱이 된다.
SELECT COUNT(*) AS remaining_demo_users FROM users WHERE email LIKE '%@lifequest.test';
```

`quests`는 지우지 않는다. 시연 중 주간 AI 퀘스트를 채택했다면 사라진 사용자를 가리키는
`owner_user_id`를 가진 행이 카탈로그에 남는다(외래 키가 없어 삭제를 막지 않고 아래 점검
질의에도 잡히지 않는다). 배정 풀은 `owner_user_id IS NULL`만 보므로 시연에는 지장이 없다.

> 표가 늘어나면 이 목록도 늘어난다. 실행 전에 다음 셋으로 빠진 곳이 없는지 확인한다.
>
> ```sql
> -- ① users를 외래 키로 참조하는 표. 표는 21개이고 열은 24개다(친구·친구요청·멤버는 열이 둘씩).
> SELECT k.TABLE_NAME, k.COLUMN_NAME
> FROM information_schema.KEY_COLUMN_USAGE k
> WHERE k.TABLE_SCHEMA = DATABASE() AND k.REFERENCED_TABLE_NAME = 'users';
>
> -- ② 외래 키 없이 user_id만 둔 표. ①에 안 나오므로 따로 봐야 한다. 이미 넷 있다
> --    (quest_completions · user_daily_quests · quest_assignment_markers · weekly_ai_quest_claims).
> SELECT TABLE_NAME, COLUMN_NAME
> FROM information_schema.COLUMNS
> WHERE TABLE_SCHEMA = DATABASE() AND COLUMN_NAME LIKE '%user_id'
> ORDER BY TABLE_NAME;
>
> -- ③ 부모 기준으로도 지워야 하는 자식 표. 위에서 부모를 지우는 세 표를 참조하는 곳이다.
> SELECT k.TABLE_NAME, k.COLUMN_NAME, k.REFERENCED_TABLE_NAME
> FROM information_schema.KEY_COLUMN_USAGE k
> WHERE k.TABLE_SCHEMA = DATABASE()
>   AND k.REFERENCED_TABLE_NAME IN ('quest_proof_posts', 'quest_groups', 'group_quests');
> ```

지운 뒤 `demo` 프로파일로 다시 띄우면 새로 적재된다. 인증 사진(백엔드 실행 디렉터리의
`uploads/proof/demo-proof-*.png`)은 남아 있어도 무해하며 재실행 시 덮어쓴다.

## 5. Flutter 공통 실행

### IDE에서 ▶ 한 번으로 실행

IntelliJ IDEA 또는 Android Studio에서 저장소 루트 `LifeQuest`를 연다. 상단의
Run Configuration 목록에서 `LifeQuest Flutter`를 한 번 선택한 뒤 ▶ 버튼을
누르면 된다. 저장소의 `.run/LifeQuest Flutter.run.xml`을 공유하므로 개발자가
별도의 Flutter 실행 설정이나 `--dart-define`을 만들 필요가 없다.

목록에 설정이 보이지 않으면 다음을 확인한다.

- IDE에 Flutter와 Dart 플러그인이 활성화되어 있는지
- Flutter SDK가 3.44.8로 설정되어 있는지
- `app/pubspec.yaml`이 IDE에서 Flutter 모듈로 인식되는지
- 저장소 루트를 다시 열거나 Gradle/Flutter 프로젝트를 다시 로드했는지

모바일 기기가 하나면 자동 선택된다. 여러 기기를 항상 연결해 두는 PC는 먼저
기기 ID를 확인한다.

```bash
dart run tool/run_app.dart --list-devices
```

그 PC의 `.env`에 기본 기기를 한 번 저장하면 이후에는 ▶ 버튼만 누르면 된다.

```dotenv
FLUTTER_DEVICE_ID=기기_ID
```

이 값은 Git에 올라가지 않으므로 Windows PC, Mac, 개발자마다 다르게 지정해도
된다.

### VS Code에서 F5로 실행

저장소 루트 `LifeQuest`를 VS Code로 연다. 처음 열 때 추천되는 Dart와 Flutter
확장을 설치한 뒤 다음과 같이 실행한다.

1. 왼쪽 `Run and Debug` 패널을 연다.
2. 실행 목록에서 `LifeQuest Flutter`를 선택한다.
3. F5 또는 ▶ 버튼을 누른다.

공유 설정 `.vscode/launch.json`이 IntelliJ/Android Studio와 동일한
`tool/run_app.dart`를 실행한다. VS Code 하단 상태 표시줄에서 선택한 Flutter
기기 ID를 공통 실행기에 전달하므로, 다음 실행부터 선택한 기기를 사용한다.
CLI와 IntelliJ/Android Studio에서 여러 기기를 사용하는 경우에는 앞에서 설명한
`.env`의 `FLUTTER_DEVICE_ID`를 사용한다.

### 터미널에서 실행

Windows와 macOS 모두 저장소 루트에서 같은 명령을 사용한다.

```bash
dart run tool/run_app.dart
```

공통 실행기는 다음을 자동 처리한다.

- Flutter 3.44.8 확인
- `.env`의 Google 웹 클라이언트 ID 전달
- 연결된 Android/iOS 모바일 기기가 하나이면 자동 선택
- Android 에뮬레이터는 `http://10.0.2.2:8080/api` 사용
- iOS 시뮬레이터는 `http://127.0.0.1:8080/api` 사용
- USB Android 실기기는 `adb reverse` 설정
- PC별 SDK 절대 경로를 저장소에 기록하지 않음

실행 가능한 기기 확인:

```bash
dart run tool/run_app.dart --list-devices
```

모바일 기기가 여러 개면 ID를 지정한다.

```bash
dart run tool/run_app.dart --device 기기_ID
```

종류로 제한할 수도 있다.

```bash
# Android 에뮬레이터
dart run tool/run_app.dart --target emulator

# USB Android 실기기
dart run tool/run_app.dart --target usb

# iOS 기기 또는 시뮬레이터
dart run tool/run_app.dart --target ios
```

추가 Flutter 인자는 `--` 뒤에 전달한다.

```bash
dart run tool/run_app.dart -- --profile
```

기존 Windows `run-app.ps1`은 호환용 얇은 래퍼로 유지한다. 새 문서와 자동화는
공통 Dart 명령을 기준으로 한다.

### Wi-Fi/LAN과 iOS 실기기

Wi-Fi로 연결한 Android 기기와 iOS 실기기는 개발 PC의 LAN 주소로 백엔드에
접속해야 한다. `.env`에 현재 PC의 주소를 입력한다.

```dotenv
FLUTTER_API_BASE_URL=http://192.168.x.x:8080/api
```

```bash
dart run tool/run_app.dart --lan
```

한 번만 다른 주소를 사용할 수도 있다.

```bash
dart run tool/run_app.dart \
  --api-base-url http://192.168.x.x:8080/api
```

PowerShell에서는 한 줄로 입력하거나 줄 끝에 백틱을 사용한다. 기기와 PC가 같은
네트워크에 있어야 하고, OS 방화벽에서 TCP 8080 접속 허용이 필요할 수 있다.

## 6. Google 로그인

Google Cloud 프로젝트에는 다음 클라이언트가 필요하다.

- 웹 애플리케이션: 루트 `.env`의 `GOOGLE_CLIENT_ID`
- Android: 패키지 `com.lifequest.life_quest`와 공동 debug keystore SHA-1
- iOS: Runner Bundle ID, `GIDClientID`, reversed client ID URL scheme

공동 개발용 키 `app/android/app/debug.keystore`는 모든 PC에서 동일한 Android
OAuth SHA-1을 사용하기 위해 Git에 포함되어 있다. 릴리스에는 사용하지 않는다.

서명 보고서:

```powershell
# Windows
cd app\android
.\gradlew.bat signingReport
```

```bash
# macOS
cd app/android
./gradlew signingReport
```

iOS 설정과 릴리스 업로드 키 절차는 `07-auth-setup.md`를 참고한다.

## 7. 테스트와 빌드

백엔드:

```powershell
# Windows
cd backend
.\gradlew.bat test
```

```bash
# macOS
cd backend
./gradlew test
```

Flutter:

```bash
cd app
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Android release App Bundle에는 별도의 업로드 키가 필요하다.
`app/android/key.properties.example`을 `key.properties`로 복사하고 저장소 밖에
보관한 키 경로와 비밀번호를 입력한다. 파일이 없으면 release 빌드는 의도적으로
실패한다.

## 8. 로컬 경로와 캐시 정책

다음 파일과 디렉터리는 PC별 절대 경로나 캐시를 포함하므로 Git에 커밋하지 않는다.

- `app/android/local.properties`
- `app/.dart_tool`
- `app/.flutter-plugins-dependencies`
- `app/build`
- `app/android/.gradle`, `app/android/.kotlin`
- `app/ios/Flutter/Generated.xcconfig`
- `app/ios/Flutter/flutter_export_environment.sh`
- `app/ios/Pods`

저장소를 다른 경로로 옮기거나 Flutter SDK를 바꾼 뒤에는 아래 기본 초기화만 먼저
실행한다.

```bash
cd app
flutter clean
flutter pub get
```

Windows에서 프로젝트와 Pub 캐시가 서로 다른 드라이브에 있으면, 클린 직후 첫
Android 빌드에서 Kotlin 증분 캐시가 상대 경로를 계산하지 못해 스택트레이스를
출력하고 전체 컴파일로 전환할 수 있다. 캐시가 만들어진 다음 빌드부터 정상적인
증분 빌드가 된다면 추가 조치 없이 사용한다. 증분 컴파일을 전역으로 끄면 모든
빌드가 느려지므로 이 프로젝트에서는 `kotlin.incremental=false`를 사용하지 않는다.

두 번째 이후 빌드에서도 같은 오류와 전체 컴파일이 반복되는 경우에만 다음 순서로
처리한다.

1. 실행 중인 Flutter, Android Studio 및 Gradle 작업을 종료한다.
2. `flutter clean`과 `flutter pub get`을 실행한다.
3. 계속 반복되면 프로젝트 내부 `app/android/.gradle`과
   `app/android/.kotlin`을 삭제하고 다시 빌드한다.
4. 마지막 대안으로 해당 Windows PC의 `PUB_CACHE`를 프로젝트와 같은 드라이브로
   옮긴다.

전역 Pub 캐시는 다른 프로젝트도 함께 사용하므로 기본 복구 과정에서 삭제하지
않는다.

## 9. 자주 발생하는 오류

### Flutter 버전 불일치

`flutter --version`이 3.44.8인지 확인한다. FVM을 사용한다면 `fvm install`,
`fvm use` 후 FVM의 Flutter가 PATH에서 선택되도록 설정한다.

### MySQL `Access denied`

- 로컬 MySQL이 실행 중인지 확인
- `.env`와 실제 MySQL 계정의 사용자·비밀번호가 같은지 확인
- Docker MySQL과 설치형 MySQL이 동시에 3306 포트를 쓰지 않는지 확인
- Docker 볼륨 생성 뒤 비밀번호만 바꾼 것은 아닌지 확인

### 앱에서 백엔드 연결 실패

- PC에서 `/actuator/health`가 응답하는지 확인
- Android 에뮬레이터와 iOS 시뮬레이터는 기본 실행 사용
- USB Android 기기는 `--target usb` 사용
- Wi-Fi 기기와 iOS 실기기는 `--lan`, LAN IP 및 방화벽 확인

### 기기가 여러 개라는 안내

`dart run tool/run_app.dart --list-devices`로 ID를 확인하고
`--device 기기_ID`를 지정한다.

### PowerShell 호환 래퍼 실행 차단

공통 명령 `dart run tool/run_app.dart`는 PowerShell 스크립트 실행 정책의 영향을
받지 않는다. 호환용 `run-app.ps1`을 꼭 사용해야 하면 현재 터미널에서만 다음과
같이 실행할 수 있다.

```powershell
powershell -ExecutionPolicy Bypass -File .\run-app.ps1
```

조직에서 관리하는 PC라면 해당 조직의 정책을 우선한다.
