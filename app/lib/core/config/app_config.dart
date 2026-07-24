class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  /// Google Cloud Console의 "웹 애플리케이션" OAuth 클라이언트 ID.
  /// 백엔드 GOOGLE_CLIENT_ID와 반드시 같은 값이어야 한다.
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// iOS OAuth 클라이언트 ID. Android에서는 빈 값으로 둬도 된다.
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  /// 마이페이지 하단 표기용. `pubspec.yaml`의 version과 함께 올린다.
  static const appVersion = '0.1.0';
}
