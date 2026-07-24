# 08. 로컬 실행 가이드

이 문서는 새 Windows PC에서 저장소를 받은 뒤 Spring Boot 백엔드와 Flutter
Android 앱을 실행하는 전체 절차를 설명한다. 로컬 설정 원본은 저장소 루트의
`.env` 하나이며, 이 파일은 Git에 커밋하지 않는다.

## 1. 준비 프로그램

- Git
- Java 17
- Flutter stable 3.38 이상
- Android Studio와 Android SDK Platform-Tools
- 다음 중 하나
  - Docker Desktop
  - 로컬 MySQL 8.x

설치 확인:

```powershell
git --version
java -version
flutter doctor
```

`flutter doctor`에서 Android toolchain과 연결할 기기 관련 항목을 확인한다.

## 2. 최초 설정

저장소 루트에서 실행한다.

```powershell
Copy-Item .env.example .env
```

`.env`에서 최소한 다음 값을 현재 PC 환경에 맞게 설정한다.

```dotenv
DB_URL=jdbc:mysql://localhost:3306/lifequest?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Seoul
DB_USERNAME=lifequest
DB_PASSWORD=로컬_MYSQL_비밀번호

JWT_SECRET=최소_32자_이상의_임의_문자열

# Google Cloud Console의 "웹 애플리케이션" 클라이언트 ID
GOOGLE_CLIENT_ID=숫자-문자열.apps.googleusercontent.com
```

`GOOGLE_CLIENT_ID`에는 Android 클라이언트 ID가 아니라 `LifeQuest Server`
웹 애플리케이션 클라이언트 ID를 넣는다. OAuth `client_secret`은 백엔드와
Flutter 실행에 사용하지 않는다.

Flutter 패키지는 최초 한 번 내려받는다.

```powershell
cd app
flutter pub get
cd ..
```

## 3. MySQL 실행

### 방법 A: Docker MySQL

저장소 루트에서 실행한다.

```powershell
docker compose up -d
docker compose ps
```

`lifequest-mysql` 상태가 healthy가 되면 사용할 수 있다. 컨테이너의 DB 이름,
사용자와 비밀번호는 루트 `.env`의 `MYSQL_*` 값으로 생성된다.

주의: MySQL 볼륨이 이미 생성된 뒤 `.env`의 `MYSQL_PASSWORD`를 변경해도 기존
DB 사용자의 비밀번호는 자동 변경되지 않는다.

중지:

```powershell
docker compose stop
```

### 방법 B: PC에 설치된 로컬 MySQL

MySQL 관리자 계정으로 접속하여 `.env`와 같은 사용자 및 비밀번호를 준비한다.

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

SQL의 비밀번호와 `.env`의 `DB_PASSWORD`가 반드시 같아야 한다.

## 4. Spring Boot 실행

첫 번째 PowerShell에서 실행한다.

```powershell
cd backend
.\gradlew.bat bootRun
```

Spring Boot는 다음 위치의 `.env`를 자동 탐색한다.

- `backend`에서 실행: `../.env`
- 저장소 루트 또는 IDE에서 실행: `./.env`

Flyway가 시작 시 DB 스키마를 자동 적용한다. 정상 실행 확인:

```powershell
Invoke-RestMethod http://localhost:8080/actuator/health
Invoke-RestMethod http://localhost:8080/api/system/ping
```

## 5. Flutter Android 실행

Flutter 실행은 저장소 루트의 `run-app.ps1`을 사용한다. 이 스크립트는 루트
`.env`에서 공개 가능한 Google 웹 클라이언트 ID만 읽어 `--dart-define`으로
전달한다. DB 비밀번호와 JWT 키는 앱에 전달하지 않는다.

### Android Studio 에뮬레이터

에뮬레이터를 먼저 켠 뒤 저장소 루트에서 실행한다.

```powershell
.\run-app.ps1
```

표준 Android 에뮬레이터는 모든 PC에서 호스트 PC를 `10.0.2.2`로 접근하므로
PC별 IP 설정이 필요 없다.

### USB 연결 Android 실기기

휴대전화의 개발자 옵션과 USB 디버깅을 켜고 PC 연결을 허용한다.

```powershell
flutter devices
.\run-app.ps1 -Target usb
```

스크립트가 다음 연결을 자동 설정한다.

```text
휴대전화 127.0.0.1:8080 → USB → 개발 PC 127.0.0.1:8080
```

따라서 PC의 LAN IP를 입력할 필요가 없다. 여러 기기가 연결되어 있다면:

```powershell
.\run-app.ps1 -Target usb -DeviceId 기기_ID
```

`기기_ID`는 `flutter devices`에서 확인한다.

### Wi-Fi/LAN 연결 실기기

이 방식에서만 PC별 LAN IP가 필요하다. 루트 `.env`에 입력한다.

```dotenv
FLUTTER_API_BASE_URL=http://192.168.x.x:8080/api
```

실행:

```powershell
.\run-app.ps1 -Target lan
```

`.env`를 바꾸지 않고 한 번만 지정할 수도 있다.

```powershell
.\run-app.ps1 -Target lan `
  -ApiBaseUrl http://192.168.x.x:8080/api
```

휴대전화와 PC가 같은 네트워크에 있어야 하며 Windows 방화벽에서 TCP 8080
접속을 허용해야 할 수 있다.

## 6. Google 로그인 확인

Google Cloud 프로젝트에는 다음 클라이언트가 필요하다.

- 웹 애플리케이션: 루트 `.env`의 `GOOGLE_CLIENT_ID`
- Android:
  - 패키지 이름 `com.lifequest.life_quest`
  - 현재 PC의 debug keystore SHA-1
- iOS: iOS 네이티브 설정용이며 Windows Android 실행에는 사용하지 않음

현재 PC의 Android SHA-1 확인:

```powershell
cd app\android
.\gradlew.bat signingReport
```

`Variant: debug`의 SHA1을 Google Cloud Console의 Android 클라이언트에
등록한다. 새 PC는 일반적으로 다른 debug keystore를 만들기 때문에 새 PC의
SHA-1도 별도로 등록해야 한다.

Google OAuth 설정 변경은 반영까지 시간이 걸릴 수 있다. `.env`의
`GOOGLE_CLIENT_ID`를 변경했다면 다음을 모두 수행한다.

1. Spring Boot 완전 종료 후 재실행
2. Flutter 실행 완전 종료
3. `run-app.ps1`로 Flutter 재실행

Hot reload와 hot restart는 `--dart-define` 값을 다시 주입하지 않는다.

Google 인증 이메일이 기존 일반회원 이메일과 같으면 새 회원을 만들지 않고
기존 회원에 Google 로그인 수단을 연결한다. 기존 닉네임과 진행도가 유지되는
것이 정상 동작이다.

## 7. 테스트와 빌드

백엔드 테스트:

```powershell
cd backend
.\gradlew.bat test
```

Flutter 검사:

```powershell
cd app
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Android debug APK:

```powershell
cd app
flutter build apk --debug
```

생성 위치:

```text
app/build/app/outputs/flutter-apk/app-debug.apk
```

## 8. 자주 발생하는 오류

### MySQL `Access denied`

다음을 확인한다.

- 로컬 MySQL이 실행 중인지
- `.env`의 `DB_USERNAME`, `DB_PASSWORD`가 실제 MySQL 계정과 같은지
- Docker MySQL과 PC 설치형 MySQL이 동시에 3306 포트를 사용하지 않는지
- Docker 볼륨 생성 후 비밀번호만 변경한 것은 아닌지

### Google `Developer console is not set up correctly`

다음을 확인한다.

- `.env`에는 웹 애플리케이션 클라이언트 ID가 들어 있는지
- Android 클라이언트 패키지가 `com.lifequest.life_quest`인지
- 현재 PC의 debug SHA-1이 Android 클라이언트에 등록되어 있는지
- 콘솔 변경 후 충분히 기다리고 앱을 완전히 다시 실행했는지

### 앱에서 백엔드 연결 실패

- PC 브라우저나 PowerShell에서 `/actuator/health`가 응답하는지 확인
- 에뮬레이터는 `run-app.ps1` 기본 모드 사용
- USB 기기는 `-Target usb` 사용
- Wi-Fi 기기는 PC LAN IP와 방화벽 확인

### PowerShell 스크립트 실행 차단

현재 터미널에서만 우회 실행할 수 있다.

```powershell
powershell -ExecutionPolicy Bypass -File .\run-app.ps1
```

조직에서 관리하는 PC라면 해당 조직의 PowerShell 정책을 우선한다.
