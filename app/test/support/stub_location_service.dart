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

/// 화면 테스트의 ProviderScope에 얹는다. 위치를 쓰지 않는 화면도 포함해서 두는 편이 안전하다 —
/// 어느 화면이 오늘의 퀘스트를 읽는지는 위젯 트리를 따라가 봐야 알 수 있다.
///
/// 좌표가 필요한 테스트는 [locationServiceProvider]를 직접 덮어 [StubLocationService]에
/// 위치를 넘긴다. 타입 이름을 적지 않는 것은 Riverpod 3의 `flutter_riverpod`이 `Override`를
/// 재수출하지 않아서다 — 추론에 맡기면 그 이름이 필요 없다.
final stubLocation = locationServiceProvider.overrideWithValue(
  const StubLocationService(),
);
