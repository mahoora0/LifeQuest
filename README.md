# LifeQuest

현실의 활동을 퀘스트처럼 수행하고 경험치, 레벨, 도감, 업적을 수집하는
라이프 RPG 프로젝트입니다.

## Repository

```text
.
├── app/         Flutter Android/iOS 애플리케이션
├── backend/     Spring Boot REST API
├── docs/        기획·화면·DB·API·규칙·협업 문서
└── compose.yaml 로컬 MySQL
```

지도 SDK는 아직 선정하지 않았습니다. `app`의 지도 탭은 provider 중립적인
placeholder이며 지도 패키지, API 키, 네이티브 지도 설정은 포함하지 않습니다.

## Requirements

- Java 17
- Flutter 3.44.8
- Docker Desktop/Engine + Compose 또는 로컬 MySQL 8.x

Gradle은 `backend/gradlew`가 내려받으므로 별도 설치가 필요하지 않습니다.
Flutter 버전은 `.fvmrc`에 고정되어 있습니다. FVM을 사용하지 않아도 되지만,
PATH에서 선택되는 Flutter가 3.44.8이어야 공통 실행기가 동작합니다.

## First setup

```bash
# Windows PowerShell
Copy-Item .env.example .env

# macOS
cp .env.example .env

docker compose up -d
```

MySQL 상태 확인:

```powershell
docker compose ps
```

PC 설치형 MySQL 사용법, `.env` 항목, Android 실행 방식과 문제 해결을 포함한
전체 절차는 [`docs/08-local-run-guide.md`](docs/08-local-run-guide.md)를
참고합니다.

## Backend

Spring Boot가 저장소 루트 `.env`를 자동으로 읽습니다. `backend` 디렉터리나
저장소 루트에서 실행할 수 있으며, OS 환경 변수와 명령행 인자가 `.env`보다
우선합니다.

VS Code에서는 저장소 루트를 연 뒤 Java 프로젝트 가져오기가 끝나면
`Run and Debug`에서 `LifeQuest Backend`를 선택하고 F5 또는 ▶ 버튼을 누릅니다.
`LifeQuestApiApplication.java`를 직접 찾거나 먼저 실행할 필요가 없습니다.

```bash
cd backend

# Windows
.\gradlew.bat bootRun

# macOS
./gradlew bootRun
```

확인:

```bash
curl http://localhost:8080/actuator/health
curl http://localhost:8080/api/system/ping
```

테스트:

```bash
cd backend

# Windows
.\gradlew.bat test

# macOS
./gradlew test
```

## Flutter app

루트 `.env`의 `GOOGLE_CLIENT_ID`를 채운 뒤 저장소 루트에서 실행합니다.
스크립트가 Flutter에 필요한 공개 설정만 `--dart-define`으로 전달합니다.

IntelliJ IDEA 또는 Android Studio에서는 저장소 루트를 연 뒤 상단 실행 목록에서
`LifeQuest Flutter`를 선택하고 ▶ 버튼을 누르면 됩니다. 공유 실행 설정이
`tool/run_app.dart`를 호출하므로 Windows와 macOS에서 동일하게 동작합니다.

VS Code에서는 저장소 루트를 연 뒤 `Run and Debug` 패널에서
`LifeQuest Flutter`를 선택하고 F5 또는 ▶ 버튼을 누릅니다. 하단 상태 표시줄에서
선택한 Flutter 기기로 실행됩니다.

```bash
cd app
flutter pub get
cd ..

# 연결된 Android/iOS 모바일 기기가 하나일 때
dart run tool/run_app.dart

# 종류를 지정할 때
dart run tool/run_app.dart --target emulator
dart run tool/run_app.dart --target usb
dart run tool/run_app.dart --target ios
```

공통 실행기는 Flutter 3.44.8을 확인하고, Android 에뮬레이터에는 `10.0.2.2`,
iOS 시뮬레이터에는 `127.0.0.1`을 사용합니다. USB Android 실기기에는
`adb reverse`를 설정하므로 PC별 IP 입력이 필요 없습니다.

Wi-Fi 연결 기기와 iOS 실기기는 개발 PC의 LAN IP가 필요합니다. `.env`에
`FLUTTER_API_BASE_URL=http://192.168.x.x:8080/api`를 입력한 뒤 실행합니다.

```bash
dart run tool/run_app.dart --lan
```

검증:

```bash
cd app
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

## Environment variables

| 이름 | 용도 |
|---|---|
| `DB_URL` | Spring Boot MySQL JDBC URL |
| `DB_USERNAME` | 애플리케이션 DB 사용자 |
| `DB_PASSWORD` | 애플리케이션 DB 비밀번호 |
| `JWT_SECRET` | HS256 JWT 서명 키, 최소 32자 |
| `JWT_ACCESS_TOKEN_SECONDS` | 액세스 토큰 유효 시간(기본 900초) |
| `JWT_REFRESH_TOKEN_SECONDS` | 리프레시 토큰 유효 시간(기본 14일) |
| `GOOGLE_CLIENT_ID` | Google 웹 OAuth 클라이언트 ID(ID Token audience) |
| `FLUTTER_API_BASE_URL` | Wi-Fi/LAN 실기기용 개발 PC API 주소(선택) |
| `FLUTTER_DEVICE_ID` | 여러 기기 중 이 PC에서 기본으로 실행할 기기 ID(선택) |
| `CORS_ALLOWED_ORIGINS` | 쉼표로 구분한 허용 origin |

실제 비밀번호, JWT 키, 향후 지도 API 키는 커밋하지 않습니다.

`GOOGLE_CLIENT_ID` 하나를 백엔드 ID Token 검증과 Flutter Google 로그인에
공통으로 사용합니다. 클라이언트 시크릿은 Flutter에 전달하지 않습니다.
iOS 네이티브 OAuth 설정은 `docs/07-auth-setup.md`를 참고합니다.

## Development rules

- API 응답과 오류 코드는 `docs/04-api-spec.md`를 기준으로 합니다.
- DB 변경은 `backend/src/main/resources/db/migration`에 새 Flyway 파일로 추가합니다.
- 기능 패키지는 백엔드의 `auth`, `user`, `quest`, `growth`, `collection`,
  `social`, `admin` 경계를 유지합니다.
- Flutter는 기능별 `features/*`와 공통 `core`, `shared` 구조를 유지합니다.
- PR 전 백엔드 테스트와 Flutter analyze/test를 모두 통과시킵니다.
