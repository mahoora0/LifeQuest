import 'package:dio/dio.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/achievement/data/achievement_dto.dart';
import 'package:life_quest/shared/data/json_reader.dart';
import 'package:life_quest/shared/data/sample_data.dart';

/// 업적 · 칭호(S-15·S-16) 조회.
///
/// ⚠ 백엔드에 achievement 컨트롤러가 아직 없어 두 경로 모두 404다(대표 칭호·배지
/// 지정은 `/users/me/titles`·`/badges`로 이미 동작한다). 화면을 검토할 수 있도록
/// [LqSampleData.orSample]이 **`LQ_SAMPLES`를 켰고 컨트롤러가 없을 때만** 표본으로
/// 떨어지고, 서버가 열리면 저절로 물러난다.
///
// TODO(server): GET /achievements · GET /users/me/achievements 개설 시 표본
//  상수(_sampleAchievements)를 지운다. 호출 코드는 실경로를 가리키므로 그대로 둔다.
class AchievementRepository {
  const AchievementRepository(this._dio);

  final Dio _dio;

  /// 업적 목록(`/achievements`)에 내 달성 현황(`/users/me/achievements`)을 덮어쓴다.
  Future<AchievementOverview> fetchOverview() => LqSampleData.orSample(
    _fetchOverview,
    () => const AchievementOverview(achievements: _sampleAchievements),
  );

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

  /// 시안(업적·칭호 화면)의 "달성한 업적 24 / 78"을 줄인 표본이다. 실제 사용자
  /// 데이터가 아니며 디버그 빌드에서만 쓰인다.
  ///
  /// 미달성 비밀 업적은 서버가 이름·조건을 마스킹해 내려주므로 표본도 그렇게 둔다 —
  /// 여기서 실제 이름을 적으면 마스킹 처리 경로가 화면에서 검증되지 않는다.
  /// 화면은 빈 이름을 "비밀 업적"으로 대체하므로 마스킹은 `name: ''`로 표현한다.
  static const _sampleAchievements = [
    Achievement(
      id: 1,
      name: '첫 걸음',
      achieved: true,
      secret: false,
      condition: '퀘스트를 처음 완료해요',
      expReward: 20,
    ),
    Achievement(
      id: 2,
      name: '동네 탐험가',
      achieved: true,
      secret: false,
      condition: '위치 퀘스트를 10번 인증해요',
      expReward: 60,
    ),
    Achievement(
      id: 3,
      name: '꾸준한 모험가',
      achieved: false,
      secret: false,
      condition: '퀘스트를 50번 완료해요',
      currentValue: 32,
      requiredValue: 50,
      expReward: 80,
    ),
    Achievement(
      id: 4,
      name: '길 위의 수집가',
      achieved: false,
      secret: false,
      condition: '도감 항목을 60개 모아요',
      currentValue: 42,
      requiredValue: 60,
      expReward: 100,
    ),
    Achievement(id: 5, name: '', achieved: false, secret: true, expReward: 120),
    Achievement(
      id: 6,
      name: '야행성 탐험가',
      achieved: true,
      secret: true,
      condition: '자정 넘어 퀘스트를 5번 완료했어요',
      expReward: 120,
    ),
  ];
}
