class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  /// 마이페이지 하단 표기용. `pubspec.yaml`의 version과 함께 올린다.
  static const appVersion = '0.1.0';
}
