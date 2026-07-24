import 'package:dio/dio.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/shared/data/json_reader.dart';

/// 퀘스트·GPS 인증 도메인의 유일한 HTTP 접점.
/// 위젯에서 dio를 직접 호출하지 않는다.
class QuestRepository {
  const QuestRepository(this._dio);

  final Dio _dio;

  /// `GET /quests/today`
  Future<TodayQuests> fetchToday() => _guard(() async {
    final response = await _dio.get<dynamic>('/quests/today');
    return TodayQuests.fromJson(response.data);
  });

  /// `GET /quests/{questId}`
  Future<Quest> fetchQuest(int questId) => _guard(() async {
    final response = await _dio.get<dynamic>('/quests/$questId');
    return Quest.fromJson(asMap(response.data));
  });

  /// `GET /quests/nearby`
  Future<List<DailyQuest>> fetchNearby({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) => _guard(() async {
    final response = await _dio.get<dynamic>(
      '/quests/nearby',
      queryParameters: {
        'lat': latitude,
        'lng': longitude,
        'radiusKm': radiusKm,
      },
    );
    final body = asMap(response.data);
    return asMapList(
      pick(body, ['quests', 'content', 'items']),
    ).map(DailyQuest.fromJson).toList();
  });

  /// `POST /daily-quests/{dailyQuestId}/complete`
  ///
  /// 좌표·정확도는 `completion_type = LOCATION`인 퀘스트에만 싣는다.
  /// SELF_REPORT는 본문 없이 호출한다(`04-api-spec.md` §4).
  Future<QuestCompletionResult> complete(
    int dailyQuestId, {
    double? latitude,
    double? longitude,
    double? accuracy,
  }) => _guard(() async {
    final hasLocation =
        latitude != null && longitude != null && accuracy != null;
    final response = await _dio.post<dynamic>(
      '/daily-quests/$dailyQuestId/complete',
      data: hasLocation
          ? {
              'latitude': latitude,
              'longitude': longitude,
              'accuracy': accuracy,
            }
          : null,
    );
    return QuestCompletionResult.fromJson(response.data);
  });

  /// `GET /users/me/quests/history` — 마이페이지 완료 카운트용.
  Future<QuestHistoryPage> fetchHistory({int page = 0, int size = 20}) =>
      _guard(() async {
        final response = await _dio.get<dynamic>(
          '/users/me/quests/history',
          queryParameters: {'page': page, 'size': size},
        );
        return QuestHistoryPage.fromJson(response.data);
      });

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }
}

/// 완료 기록 페이지(마이페이지는 `totalElements`만 사용).
class QuestHistoryPage {
  const QuestHistoryPage({required this.totalElements, required this.content});

  final int totalElements;
  final List<Map<String, dynamic>> content;

  factory QuestHistoryPage.fromJson(Object? body) {
    final json = asMap(body);
    final content = asMapList(json['content']);
    return QuestHistoryPage(
      totalElements: asInt(json['totalElements']) ?? content.length,
      content: content,
    );
  }
}
