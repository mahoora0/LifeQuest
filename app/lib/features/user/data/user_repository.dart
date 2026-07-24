import 'package:dio/dio.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/user/data/user_dto.dart';

class UserRepository {
  const UserRepository(this._dio);

  final Dio _dio;

  Future<UserProfile> fetchMe() => _guard(() async {
    final response = await _dio.get<dynamic>('/users/me');
    return UserProfile.fromJson(response.data);
  });

  Future<LevelStatus> fetchLevel() => _guard(() async {
    final response = await _dio.get<dynamic>('/users/me/level');
    return LevelStatus.fromJson(response.data);
  });

  Future<TitleCollection> fetchTitles() => _guard(() async {
    final response = await _dio.get<dynamic>('/users/me/titles');
    return TitleCollection.fromJson(response.data);
  });

  /// 대표 칭호 설정. 해제는 `titleId = null`.
  Future<void> updateRepresentativeTitle(int? titleId) => _guard(() async {
    await _dio.patch<dynamic>('/users/me/title', data: {'titleId': titleId});
  });

  Future<RewardHistory> fetchRewards() => _guard(() async {
    final response = await _dio.get<dynamic>(
      '/users/me/rewards',
      queryParameters: const {'page': 0, 'size': 20},
    );
    return RewardHistory.fromJson(response.data);
  });

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }
}
