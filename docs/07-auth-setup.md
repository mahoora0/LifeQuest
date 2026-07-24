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
   - 개발·배포 서명 인증서의 SHA-1을 각각 등록한다.
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

```powershell
# Android 에뮬레이터
.\run-app.ps1

# USB 연결 Android 실기기
.\run-app.ps1 -Target usb

# Wi-Fi/LAN 연결 Android 실기기
.\run-app.ps1 -Target lan
```

전체 최초 설정과 실행 방식은 `08-local-run-guide.md`를 참고한다.

ID Token 자체를 회원 식별자로 저장하지 않는다. Google 계정의 안정적인 `sub`를
`social_accounts.provider_user_id`에 저장하며, Google이 검증한 이메일과 기존
회원 이메일이 같으면 해당 회원에 Google 로그인 수단을 연결한다.
