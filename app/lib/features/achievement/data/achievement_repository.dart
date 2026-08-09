import 'package:dio/dio.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/achievement/data/achievement_dto.dart';
import 'package:life_quest/shared/data/json_reader.dart';

/// 업적 · 칭호(S-15·S-16) 조회.
///
/// 전체 업적과 사용자의 실제 달성 현황을 서버에서 조회한다.
/// 백엔드에 경로가 아직 없다면 가짜 데이터로 대체하지 않고 준비 중 상태를 표시한다.
class AchievementRepository {
  const AchievementRepository(this._dio);

  final Dio _dio;

  /// 업적 목록(`/achievements`)에 내 달성 현황(`/users/me/achievements`)을 덮어쓴다.
  Future<AchievementOverview> fetchOverview() => _fetchOverview();

  Future<AchievementOverview> _fetchOverview() => _guard(() async {
    final responses = await Future.wait([
      _dio.get<dynamic>('/achievements'),
      _dio.get<dynamic>('/users/me/achievements'),
    ]);

    final all = _read(responses[0].data);
    final mine = {
      for (final achievement in _read(responses[1].data))
        achievement.id: achievement,
    };

    return AchievementOverview(
      achievements: [
        for (final achievement in all)
          mine[achievement.id] == null
              ? achievement
              : achievement.mergeWith(mine[achievement.id]!),
      ],
    );
  });

  List<Achievement> _read(Object? body) {
    final json = asMap(body);
    return asMapList(
      pick(json, ['achievements', 'content', 'items']),
    ).map(Achievement.fromJson).toList();
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }
}
