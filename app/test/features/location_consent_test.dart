import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:life_quest/core/location/location_service.dart';
import 'package:life_quest/features/location/application/location_consent_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 위치 권한 안내(시안 "화면 구성 규칙" §11)의 단계 판정과 재노출 규칙.
void main() {
  const deferKey = 'location.consent.deferredOn';

  ProviderContainer containerWith(LocationService service) {
    final container = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    return container;
  }

  // 하루의 경계는 자정이 아니라 04:00이다(`docs/05-business-rules.md` §1-1).
  // 아래 검증들은 `todayKey()`를 호출해 자기 자신과 비교하지 않는다 — 그렇게 하면
  // 구현이 무엇을 돌려주든 통과해서 경계 규칙을 아무것도 보장하지 못한다.
  group('논리적 일자 경계 04:00', () {
    test('밤 11시와 다음날 새벽 1시는 같은 날이다', () {
      // 이 케이스가 규칙의 존재 이유다 — 자정 경계에서는 밤에 미룬 사람이
      // 자정을 넘기자마자 안내를 한 번 더 봤다.
      expect(
        LocationConsentNotifier.todayKey(DateTime(2026, 3, 31, 23, 0)),
        LocationConsentNotifier.todayKey(DateTime(2026, 4, 1, 1, 0)),
      );
    });

    test('04:00 이전은 전날로 센다', () {
      expect(
        LocationConsentNotifier.todayKey(DateTime(2026, 4, 1, 3, 59)),
        '2026-03-31',
      );
    });

    test('04:00부터 당일로 넘어간다', () {
      expect(
        LocationConsentNotifier.todayKey(DateTime(2026, 4, 1, 4, 0)),
        '2026-04-01',
      );
    });

    test('월·일을 두 자리로 채운다', () {
      expect(
        LocationConsentNotifier.todayKey(DateTime(2026, 1, 5, 12, 0)),
        '2026-01-05',
      );
    });
  });

  test('아직 묻지 않았으면 전면 안내부터 띄운다', () async {
    SharedPreferences.setMockInitialValues({});
    final container = containerWith(const _FakeLocationService());

    final stage = await container.read(locationConsentProvider.future);
    expect(stage, LocationConsentStage.intro);
  });

  test('오늘 미뤘으면 전면 안내를 다시 띄우지 않는다', () async {
    SharedPreferences.setMockInitialValues({
      deferKey: LocationConsentNotifier.todayKey(),
    });
    final container = containerWith(const _FakeLocationService());

    final stage = await container.read(locationConsentProvider.future);
    // 이 단계에서는 배너·시트만 동작한다.
    expect(stage, LocationConsentStage.deferred);
    expect(stage.needsBanner, isTrue);
  });

  test('날짜가 바뀌면 다음 실행 때 한 번 더 묻는다', () async {
    SharedPreferences.setMockInitialValues({deferKey: '2020-01-01'});
    final container = containerWith(const _FakeLocationService());

    final stage = await container.read(locationConsentProvider.future);
    expect(stage, LocationConsentStage.intro);
  });

  test('권한이 있으면 두 단계 모두 사라지고 미룬 기록도 걷힌다', () async {
    SharedPreferences.setMockInitialValues({deferKey: '2020-01-01'});
    final container = containerWith(
      const _FakeLocationService(permission: LocationPermission.whileInUse),
    );

    final stage = await container.read(locationConsentProvider.future);
    expect(stage, LocationConsentStage.granted);
    expect(stage.needsBanner, isFalse);
    expect(stage.needsSheet, isFalse);

    // 남겨 두면 나중에 권한을 껐을 때 엉뚱한 날짜로 판정된다.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(deferKey), isNull);
  });

  test('영구 거부면 안내 대신 설정으로 보낼 단계가 된다', () async {
    SharedPreferences.setMockInitialValues({});
    final container = containerWith(
      const _FakeLocationService(permission: LocationPermission.deniedForever),
    );

    final stage = await container.read(locationConsentProvider.future);
    expect(stage, LocationConsentStage.blocked);
    // 배너는 남지만 전면 안내는 띄우지 않는다 — OS 팝업이 뜨지 않아 헛돈다.
    expect(stage.needsBanner, isTrue);
  });

  test('미루면 오늘 날짜가 기록된다', () async {
    SharedPreferences.setMockInitialValues({});
    final container = containerWith(const _FakeLocationService());
    await container.read(locationConsentProvider.future);

    await container.read(locationConsentProvider.notifier).defer();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(deferKey), LocationConsentNotifier.todayKey());
    expect(
      container.read(locationConsentProvider).value,
      LocationConsentStage.deferred,
    );
  });

  test('허용을 받으면 granted로 넘어가고 미룬 기록을 지운다', () async {
    SharedPreferences.setMockInitialValues({
      deferKey: LocationConsentNotifier.todayKey(),
    });
    final container = containerWith(
      const _FakeLocationService(requested: LocationPermission.whileInUse),
    );
    await container.read(locationConsentProvider.future);

    final granted = await container
        .read(locationConsentProvider.notifier)
        .request();

    expect(granted, isTrue);
    expect(
      container.read(locationConsentProvider).value,
      LocationConsentStage.granted,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(deferKey), isNull);
  });

  test('권한 판정에 실패해도 안내가 앱을 막지 않는다', () async {
    SharedPreferences.setMockInitialValues({});
    final container = containerWith(const _BrokenLocationService());

    final stage = await container.read(locationConsentProvider.future);
    // 판정을 못 하면 아무것도 띄우지 않는다.
    expect(stage, LocationConsentStage.unknown);
    expect(stage.needsBanner, isFalse);
    expect(stage.needsSheet, isFalse);
  });
}

class _FakeLocationService implements LocationService {
  const _FakeLocationService({
    this.permission = LocationPermission.denied,
    this.requested,
  });

  final LocationPermission permission;
  final LocationPermission? requested;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async =>
      requested ?? permission;

  @override
  Future<Position> getCurrentPosition() => throw UnimplementedError();

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Stream<Position> watchPosition() => const Stream.empty();

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

/// 플러그인이 없는 환경(데스크톱·CI)을 흉내 낸다.
class _BrokenLocationService implements LocationService {
  const _BrokenLocationService();

  @override
  Future<LocationPermission> checkPermission() async =>
      throw Exception('MissingPluginException');

  @override
  Future<LocationPermission> requestPermission() => throw UnimplementedError();

  @override
  Future<Position> getCurrentPosition() => throw UnimplementedError();

  @override
  Future<bool> isServiceEnabled() async => false;

  @override
  Stream<Position> watchPosition() => const Stream.empty();

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<bool> openLocationSettings() async => false;
}
