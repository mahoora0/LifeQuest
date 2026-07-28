import 'package:life_quest/core/network/api_exception.dart';

/// 서버가 아직 열리지 않은 구간에서 화면 검토용 표본을 내주는 관문.
///
/// 표본 없이 없는 엔드포인트를 호출하면 화면이 늘 오류 상태로만 보여 레이아웃과
/// 상호작용을 전혀 검토할 수 없다. 그렇다고 표본을 그대로 두면 회수를 잊었을 때
/// 사용자에게 거짓 데이터가 나간다. 이 레포에는 이미 그 선례가 있다 — 마이페이지의
/// 퀘스트 완료 수가 영구 0인 것은 회수 장치 없는 하드코딩 스텁이 살아남았기 때문이다.
///
/// 그래서 표본은 **명시적으로 켰을 때만** 나온다. 기본값이 꺼짐이라 아무 빌드에나
/// 딸려 나가지 않는다.
///
/// ```
/// flutter run --dart-define=LQ_SAMPLES=true      # 개발 중 화면 검토
/// dart run tool/run_app.dart                     # 런처가 위 플래그를 넣어 준다
/// flutter build apk                              # 플래그 없음 → 표본 없음
/// ```
///
/// 빌드 모드(`kDebugMode`)에 묶지 않은 이유 — CI의 Android job이
/// `flutter build apk --debug`로 산출물을 만든다(`.github/workflows/android-build.yml`).
/// 디버그 기준으로 두면 **팀에 실제로 배포되는 그 APK가 표본을 실데이터처럼 보여준다.**
/// 반대로 프로파일 빌드는 디버그가 아니라서 시연용으로 뽑으면 화면이 비어 버린다.
/// 노출 여부는 빌드 모드가 아니라 의도로 정해야 한다.
///
/// 회수 방법 — 저장소 메서드 본문을 Dio 호출로 바꾸고 이 클래스 호출을 지운다.
/// 남은 호출부는 `rg 'LqSampleData'` 로 한 번에 찾을 수 있다.
abstract final class LqSampleData {
  /// 표본을 내줄지. 기본값은 꺼짐이다.
  ///
  /// 테스트는 이 값을 컴파일 타임에 뒤집을 수 없으므로, 표본 경로를 검사할 때는
  /// 저장소를 직접 만들어 쓰거나 [orSample]을 직접 부른다.
  static const enabled = bool.fromEnvironment('LQ_SAMPLES');

  /// 표본을 내주기 전에 부른다. 꺼져 있으면 준비 중으로 떨어진다.
  ///
  /// 부를 엔드포인트 자체가 없는 구간(친구·알림)에 쓴다. 호출할 경로가 있으면
  /// [orSample]을 쓰는 쪽이 낫다 — 그쪽은 서버가 생기면 저절로 물러난다.
  ///
  /// 서버가 미매핑 경로에 붙이는 것과 **같은 코드**로 던진다. 다른 코드를 쓰면
  /// `isFeatureNotReady`가 이 예외를 못 알아보고 준비 중 안내 대신 오류 화면이 뜬다.
  static void guard(String feature) {
    if (enabled) return;
    throw ApiException(
      code: endpointNotFound,
      message: '$feature은(는) 아직 준비 중이에요',
      statusCode: 404,
    );
  }

  /// 실제 호출을 먼저 시도하고, **컨트롤러 자체가 없을 때만** 표본으로 떨어진다.
  ///
  /// [guard]와 달리 회수가 자동이다 — 서버가 그 경로를 열면 [call]이 성공하므로
  /// 표본은 두 번 다시 쓰이지 않는다. 지우는 것을 잊어도 가짜가 실데이터를 덮지 않는다.
  ///
  /// 떨어지는 조건을 좁게 잡았다. 백엔드가 미매핑 경로에만
  /// `ENDPOINT_NOT_FOUND`(404)를 내보내므로 그 코드만 컨트롤러 부재로 본다.
  /// 대상만 없는 `RESOURCE_NOT_FOUND`까지 받으면 서버가 붙은 뒤에도 특정 요청에서만
  /// 가짜가 나가고, 500이나 네트워크 단절까지 받으면 서버가 죽은 것을 개발 중에
  /// 알아채지 못한다.
  static Future<T> orSample<T>(
    Future<T> Function() call,
    T Function() sample,
  ) async {
    try {
      return await call();
    } on Object catch (error) {
      if (enabled && isEndpointMissing(error)) return sample();
      rethrow;
    }
  }

  /// 경로에 컨트롤러가 없는지. 서버가 그 경우에만 붙이는 코드로 판정한다.
  static bool isEndpointMissing(Object error) =>
      ApiException.from(error).code == endpointNotFound;

  /// 백엔드 `ErrorCode.ENDPOINT_NOT_FOUND`.
  static const endpointNotFound = 'ENDPOINT_NOT_FOUND';
}
