import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/shared/data/sample_data.dart';

/// 표본 데이터 관문. 회수를 잊어도 가짜가 실데이터를 덮지 않는 것이 이 장치의 목적이다.
void main() {
  // 테스트는 디버그로 돌아가므로 표본이 열려 있는 상태를 검사한다.
  // 릴리스 동작은 컴파일 상수라 여기서 뒤집을 수 없다 — guard가 던지는 예외의
  // 모양(404 + FEATURE_NOT_READY)이 준비 중 판정과 맞는지로 대신 확인한다.
  test('디버그 빌드에서는 표본이 열려 있다', () {
    expect(LqSampleData.enabled, isTrue);
    expect(() => LqSampleData.guard('알림'), returnsNormally);
  });

  test('엔드포인트가 없으면 표본으로 떨어진다', () async {
    final value = await LqSampleData.orSample(
      () async => throw const ApiException(
        code: 'NOT_FOUND',
        message: '',
        statusCode: 404,
      ),
      () => '표본',
    );

    expect(value, '표본');
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

  test('서버 장애는 표본으로 가리지 않는다', () async {
    // 500이나 네트워크 단절까지 표본으로 덮으면 서버가 죽은 것을 개발 중에 못 본다.
    await expectLater(
      LqSampleData.orSample(
        () async => throw const ApiException(
          code: 'INTERNAL_ERROR',
          message: '',
          statusCode: 500,
        ),
        () => '표본',
      ),
      throwsA(isA<ApiException>()),
    );

    await expectLater(
      LqSampleData.orSample(
        () async => throw const ApiException(
          code: ApiException.networkError,
          message: '',
        ),
        () => '표본',
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('엔드포인트는 있고 리소스만 없으면 표본으로 가지 않는다', () async {
    // RESOURCE_NOT_FOUND는 경로가 살아 있다는 뜻이라 "다시 시도"가 의미를 갖는다.
    await expectLater(
      LqSampleData.orSample(
        () async => throw const ApiException(
          code: 'RESOURCE_NOT_FOUND',
          message: '',
          statusCode: 404,
        ),
        () => '표본',
      ),
      throwsA(isA<ApiException>()),
    );
  });
}
