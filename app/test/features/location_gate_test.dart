import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/quest/domain/location_gate.dart';

void main() {
  group('evaluateLocationGate', () {
    test('반경 안 + 정확도 충분 → 인증 가능', () {
      expect(
        evaluateLocationGate(accuracy: 8, distanceM: 20, radiusM: 50),
        LocationGate.withinRadius,
      );
    });

    test('반경 밖', () {
      expect(
        evaluateLocationGate(accuracy: 8, distanceM: 80, radiusM: 50),
        LocationGate.outOfRadius,
      );
    });

    test('경계값 — 거리가 반경과 같으면 인증 가능', () {
      expect(
        evaluateLocationGate(accuracy: 8, distanceM: 50, radiusM: 50),
        LocationGate.withinRadius,
      );
    });

    test('정확도가 상한 min(radius,100)을 넘으면 차단', () {
      expect(
        evaluateLocationGate(accuracy: 60, distanceM: 10, radiusM: 50),
        LocationGate.accuracyTooLow,
      );
      // 반경이 100보다 크면 상한은 100.
      expect(
        evaluateLocationGate(accuracy: 120, distanceM: 10, radiusM: 500),
        LocationGate.accuracyTooLow,
      );
      expect(
        evaluateLocationGate(accuracy: 90, distanceM: 10, radiusM: 500),
        LocationGate.withinRadius,
      );
    });

    group('accuracy <= 0 (에뮬레이터·모의 위치)', () {
      // 서버는 accuracy > 0을 요구한다. 통과시키면 반드시 거절당할 요청을
      // 사용자에게 권하게 되고, 거절 코드가 무한 재시도 루프를 만든다.
      test('0은 완벽한 정확도가 아니라 알 수 없음으로 다룬다', () {
        expect(
          evaluateLocationGate(accuracy: 0, distanceM: 5, radiusM: 50),
          LocationGate.accuracyUnknown,
        );
      });

      test('음수도 마찬가지', () {
        expect(
          evaluateLocationGate(accuracy: -1, distanceM: 5, radiusM: 50),
          LocationGate.accuracyUnknown,
        );
      });

      test('반경 정보가 없어도 accuracy 0은 막는다', () {
        expect(
          evaluateLocationGate(accuracy: 0, distanceM: null, radiusM: null),
          LocationGate.accuracyUnknown,
        );
      });
    });

    group('반경 정보가 없을 때', () {
      // 기본값을 추측해 막으면 실제로는 인증 가능한 퀘스트를
      // 앱이 영구히 차단해 버린다. 판정은 서버에 맡긴다.
      test('거리가 아무리 멀어도 클라이언트가 막지 않는다', () {
        expect(
          evaluateLocationGate(accuracy: 8, distanceM: 5000, radiusM: null),
          LocationGate.withinRadius,
        );
      });

      test('정확도 상한은 100m로 본다', () {
        expect(
          evaluateLocationGate(accuracy: 101, distanceM: null, radiusM: null),
          LocationGate.accuracyTooLow,
        );
        expect(
          evaluateLocationGate(accuracy: 99, distanceM: null, radiusM: null),
          LocationGate.withinRadius,
        );
      });
    });

    test('거리를 모르면 반경 판정을 건너뛴다', () {
      expect(
        evaluateLocationGate(accuracy: 8, distanceM: null, radiusM: 50),
        LocationGate.withinRadius,
      );
    });
  });
}
