import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

abstract interface class LocationService {
  Future<Position> getCurrentPosition();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
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

    return Geolocator.getCurrentPosition();
  }
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
