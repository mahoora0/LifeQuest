# 07. 인증 및 Google 로그인 설정

현재 구현은 이메일/비밀번호 계정과 Google 계정을 동일한 `users` 회원에
연결한다. Google 로그인은 Flutter가 ID Token을 받고, Spring Boot가 서명·발급자·
만료·audience를 검증한 뒤 LifeQuest의 Access/Refresh Token을 발급한다.

## 토큰 정책

- Access Token: HS256 JWT, 기본 15분
- Refresh Token: 256비트 이상의 난수 opaque token, 기본 14일
- DB에는 Refresh Token 원문 대신 SHA-256 해시만 저장
- 재발급할 때 기존 Refresh Token을 즉시 폐기하고 새 토큰으로 회전
- Flutter는 두 토큰을 `flutter_secure_storage`에 저장

## Google Cloud Console

하나의 Google Cloud 프로젝트에서 다음 OAuth 클라이언트를 만든다.

1. **웹 애플리케이션** 클라이언트
   - 백엔드의 `GOOGLE_CLIENT_ID`
   - Flutter 실행 시 `GOOGLE_SERVER_CLIENT_ID`
   - 두 값은 반드시 같아야 한다.
2. **Android** 클라이언트
   - 패키지명: `com.lifequest.life_quest`
   - 공동 디버그 키와 Google Play 앱 서명 인증서의 SHA-1을 각각 등록한다.
3. **iOS** 클라이언트
   - Xcode 프로젝트의 Bundle ID와 일치시킨다.
   - `app/ios/Runner/Info.plist`의 `GIDClientID`에 등록한다.
   - Xcode `Runner` target의 URL Types에 콘솔이 제공하는 reversed client ID를
     등록한다.
   - 필요하면 `GOOGLE_IOS_CLIENT_ID` dart-define으로 네이티브 설정을
     덮어쓸 수 있다.

## 백엔드 실행

저장소 루트 `.env`에 Google 웹 클라이언트 ID와 JWT 키를 설정한다.

```dotenv
GOOGLE_CLIENT_ID=YOUR_WEB_CLIENT_ID
JWT_SECRET=replace-with-a-random-secret-at-least-32-bytes
```

```powershell
cd backend
.\gradlew.bat bootRun
```

## Flutter 실행

저장소 루트의 실행 스크립트가 `.env`의 `GOOGLE_CLIENT_ID`를 Flutter의
`GOOGLE_SERVER_CLIENT_ID`로 전달한다.

```bash
# 연결된 모바일 기기가 하나일 때
dart run tool/run_app.dart

# 기기 종류 지정
dart run tool/run_app.dart --target emulator
dart run tool/run_app.dart --target usb
dart run tool/run_app.dart --target ios

# Wi-Fi/LAN 연결 기기 또는 iOS 실기기
dart run tool/run_app.dart --lan
```

전체 최초 설정과 실행 방식은 `08-local-run-guide.md`를 참고한다.

ID Token 자체를 회원 식별자로 저장하지 않는다. Google 계정의 안정적인 `sub`를
`social_accounts.provider_user_id`에 저장하며, Google이 검증한 이메일과 기존
회원 이메일이 같으면 해당 회원에 Google 로그인 수단을 연결한다.

## Android 서명 키

### 공동 디버그 키

Android 디버그 빌드는 `app/android/app/debug.keystore`를 사용한다. 이 파일을
Git에서 프로젝트 전용 공동 디버그 키로 추적하므로, 개발자는 저장소를 받은 뒤
별도의 키 생성이나 전달 절차 없이 같은 키로 빌드한다. 이 키는 공개된 개발용
키로 간주하며 릴리스 서명, 운영 비밀, 다른 프로젝트에는 사용하지 않는다.

공동 키의 SHA-1은 다음 명령으로 확인한다.

```bash
cd app/android

# Windows
.\gradlew.bat signingReport

# macOS
./gradlew signingReport
```

`Variant: debug`의 SHA1을 Google Cloud Console의 Android OAuth 클라이언트에
등록한다. 모든 개발자가 같은 키를 사용하므로 개발자별 SHA-1 등록은 필요 없다.

### 릴리스 키

디버그 키를 배포에 사용하지 않는다. Google Play Console에서 Play App Signing을
사용하고, 로컬·CI에는 별도의 **업로드 키**만 보관한다.

1. 저장소 밖의 안전한 위치에 업로드 키를 생성한다.
2. `app/android/key.properties.example`을 `app/android/key.properties`로
   복사하고 업로드 키 경로와 비밀번호를 입력한다.
3. 키스토어, `key.properties`, 비밀번호를 Git에 커밋하지 않는다.
4. 키스토어 원본과 비밀번호를 서로 분리해 백업한다.

업로드 키는 Java 17의 `keytool`로 생성할 수 있다. 다음 명령은 PowerShell과
macOS의 `pwsh`에서 모두 사용할 수 있다.

```powershell
keytool -genkeypair -v `
  -keystore "$HOME/.android/lifequest-upload.jks" `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias lifequest-upload
```

명령이 묻는 키스토어 비밀번호와 키 비밀번호에는 충분히 긴 서로 다른 값을
사용한다. 생성 후 `key.properties`의 `storeFile`에는 절대 경로를 입력한다.
Google Play Console에서는 Play App Signing을 활성화하고 이 키의 공개 인증서를
업로드 키로 등록한다. 실제 스토어 설치본의 Google 로그인에는 업로드 키 SHA-1이
아니라 Play Console의 **앱 서명 키 인증서 SHA-1**을 Android OAuth 클라이언트에
등록한다.

`key.properties`가 없는 상태에서 release 작업을 실행하면 Gradle이 빌드를
중단한다. 따라서 릴리스가 디버그 키로 서명되는 일은 없다.
