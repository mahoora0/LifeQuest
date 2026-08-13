import 'package:geolocator/geolocator.dart';
import 'package:life_quest/core/location/location_service.dart';

/// 위젯 테스트용 위치 스텁.
///
/// `todayQuestsProvider`는 배정을 만들 때 쓸 좌표를 얻으려고 [LocationService]를 지난다
/// (`05-business-rules.md` §1-C). 테스트가 이것을 덮지 않으면 실제 geolocator 플러그인을
/// 타는데, 위젯 테스트에는 플랫폼 채널 핸들러가 없어 조회가 끝나지 않는다. 화면은 로딩
/// 스피너를 계속 그리고 `pumpAndSettle`은 정착하지 못한다.
///
/// 기본값은 **권한은 허용됐고 위치는 아직 모름**이다.
///
/// 권한을 거부 상태로 두면 홈이 위치 안내 화면을 push하는데(`home_screen.dart`의
/// `_maybeShowIntro`), 라우터 없이 화면만 띄우는 테스트에서는 그것이
/// "No GoRouter found in context"로 터진다. 안내 흐름을 재는 테스트가 아니라면
/// 조용한 쪽이 기본이어야 한다.
///
/// 위치를 `null`로 두는 것은 "허용은 했지만 아직 fix가 없다"는 흔한 상태이고,
/// 그때 서버는 카탈로그 전체에서 고른다(§1-C ①).
class StubLocationService implements LocationService {
  const StubLocationService({this.position});

  /// 돌려줄 마지막 위치. `null`이면 위치를 얻지 못한 것으로 다룬다.
  final Position? position;

  @override
  Future<Position?> getLastKnownPosition() async => position;

  @override
  Future<Position> getCurrentPosition() async {
    final known = position;
    if (known == null) {
      throw const LocationServiceException('테스트: 위치 없음');
    }
    return known;
  }

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() => checkPermission();

  @override
  Stream<Position> watchPosition() => const Stream.empty();

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<bool> openAppSettings() async => true;
}

/// 어느 경로로 위치를 얻었는지 기록한다.
///
/// **캐시(`getLastKnownPosition`)와 새 fix(`getCurrentPosition`)는 비용이 다르다.**
/// 앞쪽은 즉시 돌아오지만 뒤쪽은 콜드 스타트에서 10초를 넘길 수 있고, 게다가 조회를
/// 끝낸 뒤 geolocator가 NMEA 리스너를 메인 스레드 동기 binder로 해제해 화면이 굳는
/// 일까지 있다(볼트 `plugin-cleanup-blocks-main-thread`). 그래서 "어느 쪽을 불렀나"가
/// 곧 계약이고, 이 스텁은 그것을 재기 위해 있다.
///
/// 실제로 느리게 만들지는 않는다 — 재려는 것은 "기다렸는가"가 아니라 "불렀는가"다.
class RecordingLocationService extends StubLocationService {
  RecordingLocationService({
    required this.lastKnown,
    required this.fresh,
    this.throwOnLastKnown = false,
  });

  /// 캐시가 돌려줄 위치. `null`이면 캐시 없음.
  final Position? lastKnown;

  /// 새 fix가 돌려줄 위치.
  final Position fresh;

  /// 캐시 조회 자체가 터지는 기기를 흉내 낸다.
  final bool throwOnLastKnown;

  bool freshFixRequested = false;

  @override
  Future<Position?> getLastKnownPosition() async {
    if (throwOnLastKnown) {
      throw const LocationServiceException('테스트: 캐시 조회 실패');
    }
    return lastKnown;
  }

  @override
  Future<Position> getCurrentPosition() async {
    freshFixRequested = true;
    return fresh;
  }
}

/// 위치를 어느 경로로도 얻지 못하는 기기.
class BrokenLocationService extends StubLocationService {
  const BrokenLocationService();

  @override
  Future<Position?> getLastKnownPosition() =>
      throw const LocationServiceException('테스트: 캐시 없음');

  @override
  Future<Position> getCurrentPosition() =>
      throw const LocationServiceException('테스트: fix 실패');
}

/// 테스트용 좌표. 값 자체에는 뜻이 없고 "이 좌표가 그대로 흘러갔는가"만 본다.
Position testPosition(double latitude, double longitude) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime.utc(2026, 8, 10),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

/// 화면 테스트의 ProviderScope에 얹는다. 위치를 쓰지 않는 화면도 포함해서 두는 편이 안전하다 —
/// 어느 화면이 오늘의 퀘스트를 읽는지는 위젯 트리를 따라가 봐야 알 수 있다.
///
/// 좌표가 필요한 테스트는 [locationServiceProvider]를 직접 덮어 [StubLocationService]에
/// 위치를 넘긴다. 타입 이름을 적지 않는 것은 Riverpod 3의 `flutter_riverpod`이 `Override`를
/// 재수출하지 않아서다 — 추론에 맡기면 그 이름이 필요 없다.
final stubLocation = locationServiceProvider.overrideWithValue(
  const StubLocationService(),
);
