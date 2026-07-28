import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/shared/data/sample_data.dart';

/// 표본 데이터 관문. 회수를 잊어도 가짜가 실데이터를 덮지 않는 것이 이 장치의 목적이다.
void main() {
  group('기본값', () {
    test('플래그를 주지 않으면 표본은 꺼져 있다', () {
      // `flutter test`는 `--dart-define=LQ_SAMPLES`를 주지 않는다. CI의 Android job이
      // 만드는 `flutter build apk --debug` 산출물도 마찬가지다 — 빌드 모드에 묶지 않은
      // 이유가 이것이고, 이 단언이 그 보장을 지킨다.
      expect(LqSampleData.enabled, isFalse);
    });

    test('꺼져 있으면 guard가 준비 중으로 떨어진다', () {
      expect(
        () => LqSampleData.guard('알림'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.code, 'code', 'FEATURE_NOT_READY'),
        ),
      );
    });

    test('꺼져 있으면 컨트롤러가 없어도 표본이 나가지 않는다', () async {
      var sampleUsed = false;

      await expectLater(
        LqSampleData.orSample(
          () async => throw const ApiException(
            code: ApiException.unknownError,
            message: '',
            statusCode: 404,
          ),
          () {
            sampleUsed = true;
            return '표본';
          },
        ),
        throwsA(isA<ApiException>()),
      );
      expect(sampleUsed, isFalse);
    });
  });

  group('컨트롤러 부재 판정', () {
    test('코드 없는 404만 컨트롤러 부재로 본다', () {
      // 이 백엔드는 미매핑 경로용 핸들러가 없어 공통 envelope 없이 404가 나간다.
      expect(
        LqSampleData.isEndpointMissing(
          const ApiException(
            code: ApiException.unknownError,
            message: '',
            statusCode: 404,
          ),
        ),
        isTrue,
      );
    });

    test('살아 있는 엔드포인트가 내는 404는 코드를 달고 온다', () {
      // 코드가 붙은 404까지 표본으로 받으면 서버가 붙은 뒤에도 특정 요청에서만
      // 가짜가 나간다. RESOURCE_NOT_FOUND뿐 아니라 어떤 코드든 제외해야 한다.
      for (final code in [
        'RESOURCE_NOT_FOUND',
        'FRIEND_NOT_FOUND',
        'FORBIDDEN',
      ]) {
        expect(
          LqSampleData.isEndpointMissing(
            ApiException(code: code, message: '', statusCode: 404),
          ),
          isFalse,
          reason: code,
        );
      }
    });

    test('서버 장애와 네트워크 단절은 컨트롤러 부재가 아니다', () {
      // 표본으로 가리면 서버가 죽은 것을 개발 중에 알아채지 못한다.
      expect(
        LqSampleData.isEndpointMissing(
          const ApiException(
            code: ApiException.unknownError,
            message: '',
            statusCode: 500,
          ),
        ),
        isFalse,
      );
      expect(
        LqSampleData.isEndpointMissing(
          const ApiException(code: ApiException.networkError, message: ''),
        ),
        isFalse,
      );
    });
  });

  test('서버가 응답하면 표본은 쓰이지 않는다', () async {
    var sampleUsed = false;

    final value = await LqSampleData.orSample(() async => '실데이터', () {
      sampleUsed = true;
      return '표본';
    });

    // 회수가 자동이라는 근거 — 경로가 열리는 순간 표본은 두 번 다시 안 쓰인다.
    expect(value, '실데이터');
    expect(sampleUsed, isFalse);
  });
}
