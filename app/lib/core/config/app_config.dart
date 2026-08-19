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

  /// 네이버 클라우드 플랫폼 Maps(Dynamic Map) Client ID.
  ///
  /// 비어 있으면 지도를 초기화하지 않고 대체 화면으로 넘어간다. CI의 `flutter test`와
  /// `build apk`는 이 값을 주입하지 않으므로, 비어 있는 상태가 정상 경로 중 하나다.
  static const naverMapClientId = String.fromEnvironment('NAVER_MAP_CLIENT_ID');

  /// 지도 SDK를 쓸 수 있는지. 키가 없으면 지도 대신 대체 화면을 그린다.
  static bool get isMapEnabled => naverMapClientId.isNotEmpty;

  /// 마이페이지 하단 표기용. `pubspec.yaml`의 version과 함께 올린다.
  static const appVersion = '0.1.0';

  static String resolveMediaUrl(String? value) {
    if (value == null || value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;

    final api = Uri.parse(apiBaseUrl);
    return api
        .replace(path: value.startsWith('/') ? value : '/$value')
        .toString();
  }
}
