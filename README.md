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
- Flutter stable 3.38 이상
- Docker Desktop 또는 Docker Engine + Compose

Gradle은 `backend/gradlew`가 내려받으므로 별도 설치가 필요하지 않습니다.

## First setup

```bash
cp .env.example .env
docker compose up -d
```

MySQL 상태 확인:

```bash
docker compose ps
```

## Backend

기본 로컬 DB 값은 `.env.example`과 동일합니다. 다른 값을 사용할 때는 환경
변수로 전달합니다.

```bash
cd backend
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
./gradlew test
```

## Flutter app

```bash
cd app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8080/api
```

Android 에뮬레이터에서 로컬 백엔드에 접근할 때:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
```

실기기는 개발 머신의 LAN 주소를 사용해야 합니다.

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
| `CORS_ALLOWED_ORIGINS` | 쉼표로 구분한 허용 origin |
| `API_BASE_URL` | Flutter의 `--dart-define` API 주소 |

실제 비밀번호, JWT 키, 향후 지도 API 키는 커밋하지 않습니다.

## Development rules

- API 응답과 오류 코드는 `docs/04-api-spec.md`를 기준으로 합니다.
- DB 변경은 `backend/src/main/resources/db/migration`에 새 Flyway 파일로 추가합니다.
- 기능 패키지는 백엔드의 `auth`, `user`, `quest`, `growth`, `collection`,
  `social`, `admin` 경계를 유지합니다.
- Flutter는 기능별 `features/*`와 공통 `core`, `shared` 구조를 유지합니다.
- PR 전 백엔드 테스트와 Flutter analyze/test를 모두 통과시킵니다.
