import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/core/location/geo_math.dart';

void main() {
  group('haversineDistanceM', () {
    test('같은 좌표는 0m', () {
      expect(
        haversineDistanceM(
          lat1: 37.5665,
          lng1: 126.9780,
          lat2: 37.5665,
          lng2: 126.9780,
        ),
        0,
      );
    });

    test('위도 0.001도 차이는 약 111m', () {
      final distance = haversineDistanceM(
        lat1: 37.5665,
        lng1: 126.9780,
        lat2: 37.5675,
        lng2: 126.9780,
      );
      expect(distance, closeTo(111, 1));
    });

    test('서울시청 ↔ 광화문은 약 1km 안쪽', () {
      final distance = haversineDistanceM(
        lat1: 37.5663,
        lng1: 126.9779,
        lat2: 37.5759,
        lng2: 126.9769,
      );
      expect(distance, closeTo(1070, 30));
    });

    test('경도 차이는 위도가 높을수록 짧아진다', () {
      final atEquator = haversineDistanceM(
        lat1: 0,
        lng1: 0,
        lat2: 0,
        lng2: 0.01,
      );
      final atSeoul = haversineDistanceM(
        lat1: 37.5,
        lng1: 0,
        lat2: 37.5,
        lng2: 0.01,
      );
      expect(atSeoul, lessThan(atEquator));
    });
  });

  group('accuracyLimitM', () {
    test('반경이 100m보다 작으면 반경이 상한', () {
      expect(accuracyLimitM(30), 30);
    });

    test('반경이 100m보다 크면 100m가 상한', () {
      expect(accuracyLimitM(500), 100);
    });

    test('경계값 100m', () {
      expect(accuracyLimitM(100), 100);
    });
  });
}
