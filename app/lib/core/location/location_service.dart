import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

abstract interface class LocationService {
  /// 권한·GPS 상태를 확인하고 현재 위치를 1회 조회한다.
  Future<Position> getCurrentPosition();

  /// GPS 활성화 여부.
  Future<bool> isServiceEnabled();

  /// 현재 권한 상태(요청하지 않고 조회만).
  Future<LocationPermission> checkPermission();

  /// 권한 요청. 이미 영구 거부면 그대로 반환된다.
  Future<LocationPermission> requestPermission();

  /// 실시간 위치 스트림(GPS 인증 화면용).
  Stream<Position> watchPosition();

  /// 시스템 위치 설정 화면 열기.
  Future<bool> openLocationSettings();

  /// 앱 권한 설정 화면 열기(영구 거부 복구용).
  Future<bool> openAppSettings();
}

class GeolocatorLocationService implements LocationService {
  static const _settings = LocationSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 0,
  );

  @override
  Future<Position> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationServiceException('위치 서비스가 비활성화되어 있습니다.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationServiceException('위치 권한이 필요합니다.');
    }

    return Geolocator.getCurrentPosition(locationSettings: _settings);
  }

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Stream<Position> watchPosition() =>
      Geolocator.getPositionStream(locationSettings: _settings);

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return GeolocatorLocationService();
});
