import 'package:dio/dio.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/reward/data/reward_dto.dart';

/// 레벨 진행도·다음 관문·획득 보상·주간 EXP를 한 번에 조회한다.
class RewardRepository {
  const RewardRepository([this._dio]);

  // 테스트 대역은 기존처럼 const 생성자를 쓸 수 있게 선택 값으로 둔다.
  // 실제 provider는 항상 인증 인터셉터가 붙은 Dio를 주입한다.
  final Dio? _dio;

  Future<RewardOverview> fetchOverview() async {
    final dio = _dio;
    if (dio == null) {
      throw StateError('RewardRepository requires Dio');
    }
    try {
      final response = await dio.get<dynamic>(
        '/users/me/rewards',
        queryParameters: const {'page': 0, 'size': 20},
      );
      return RewardOverview.fromJson(response.data);
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }
}
