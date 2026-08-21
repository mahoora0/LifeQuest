import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/proof/data/proof_dto.dart';
import 'package:life_quest/features/proof/data/proof_repository.dart';

void main() {
  test('인증 피드 주제를 서버 wire 값으로 전달한다', () async {
    late RequestOptions request;
    final repository = ProofRepository(
      _dio((options) {
        request = options;
        return {'items': <Object>[], 'nextCursor': null};
      }),
    );

    await repository.feed(
      tab: ProofFeedTab.all,
      category: ProofQuestCategory.natureOutdoor,
      cursor: 42,
      size: 7,
    );

    expect(request.path, '/quest-proofs');
    expect(request.queryParameters, {
      'tab': 'ALL',
      'category': 'NATURE_OUTDOOR',
      'cursor': 42,
      'size': 7,
    });
  });

  test('모든 주제 조회에는 category query를 싣지 않는다', () async {
    late RequestOptions request;
    final repository = ProofRepository(
      _dio((options) {
        request = options;
        return {'items': <Object>[], 'nextCursor': null};
      }),
    );

    await repository.feed(tab: ProofFeedTab.needsVote);

    expect(request.queryParameters.containsKey('category'), isFalse);
  });
}

Dio _dio(Map<String, dynamic> Function(RequestOptions) responseFor) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: responseFor(options),
        ),
      ),
    ),
  );
  return dio;
}
