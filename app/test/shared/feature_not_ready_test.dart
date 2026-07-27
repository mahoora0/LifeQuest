import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/shared/error/lq_error_messages.dart';

/// 서버에 컨트롤러가 아직 없는 구간(도감·업적)과 실제 조회 실패를 구분하는 판정.
/// 전자는 재시도해도 결과가 같아 오류가 아니라 준비 중으로 안내해야 한다.
void main() {
  test('컨트롤러가 없는 경로의 404는 준비 중으로 본다', () {
    // 매핑이 없으면 Spring 기본 404가 오고 envelope의 error 객체가 없다.
    final error = DioException(
      requestOptions: RequestOptions(path: '/achievements'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/achievements'),
        statusCode: 404,
        data: const {'status': 404, 'error': 'Not Found'},
      ),
      type: DioExceptionType.badResponse,
    );

    expect(isFeatureNotReady(error), isTrue);
  });

  test('서버가 코드를 실어 보낸 RESOURCE_NOT_FOUND는 오류로 남긴다', () {
    // 엔드포인트는 살아 있고 특정 리소스만 없는 경우 — "다시 시도"가 의미를 갖는다.
    const error = ApiException(
      code: 'RESOURCE_NOT_FOUND',
      message: '요청한 정보를 찾을 수 없어요.',
      statusCode: 404,
    );

    expect(isFeatureNotReady(error), isFalse);
  });

  test('네트워크 오류는 준비 중이 아니다', () {
    const error = ApiException(
      code: ApiException.networkError,
      message: '서버에 연결하지 못했어요.',
    );

    expect(isFeatureNotReady(error), isFalse);
  });

  test('500은 준비 중이 아니다', () {
    const error = ApiException(
      code: ApiException.unknownError,
      message: '',
      statusCode: 500,
    );

    expect(isFeatureNotReady(error), isFalse);
  });
}
