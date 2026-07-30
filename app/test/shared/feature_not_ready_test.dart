import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/shared/error/lq_error_messages.dart';

/// 서버에 컨트롤러가 아직 없는 구간(도감·업적)과 실제 조회 실패를 구분하는 판정.
/// 전자는 재시도해도 결과가 같아 오류가 아니라 준비 중으로 안내해야 한다.
///
/// 판정 기준이 "상태 코드 404"에서 "코드 ENDPOINT_NOT_FOUND"로 바뀌었다. 실기기에서
/// 확인해 보니 백엔드의 포괄 예외 핸들러가 스프링의 `NoResourceFoundException`까지
/// 삼켜 미매핑 경로를 **500**으로 내보내고 있었고, 그래서 이 판정이 조용히 항상
/// 거짓이라 준비 중 안내가 한 번도 뜨지 않았다. 서버가 그 경우에만 붙이는 코드를
/// 보는 쪽이 중간 계층에 흔들리지 않는다.
void main() {
  test('미매핑 경로의 ENDPOINT_NOT_FOUND는 준비 중으로 본다', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/achievements'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/achievements'),
        statusCode: 404,
        data: const {
          'success': false,
          'data': null,
          'error': {
            'code': 'ENDPOINT_NOT_FOUND',
            'message': '아직 제공되지 않는 기능입니다.',
          },
        },
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

  test('코드 없는 404는 준비 중으로 보지 않는다', () {
    // 중간 계층(리버스 프록시 등)이 낸 404는 서버의 의도가 아니다.
    final error = DioException(
      requestOptions: RequestOptions(path: '/achievements'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/achievements'),
        statusCode: 404,
        data: const {'status': 404, 'error': 'Not Found'},
      ),
      type: DioExceptionType.badResponse,
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

  test('포괄 핸들러가 삼킨 500은 준비 중이 아니다', () {
    // 실기기에서 미매핑 경로가 이 모양으로 왔다. 이걸 준비 중으로 받아 주면
    // 진짜 서버 장애까지 "준비 중"으로 가려진다 — 그래서 코드로만 판정한다.
    const error = ApiException(
      code: 'INTERNAL_SERVER_ERROR',
      message: '서버 오류가 발생했습니다.',
      statusCode: 500,
    );

    expect(isFeatureNotReady(error), isFalse);
  });
}
