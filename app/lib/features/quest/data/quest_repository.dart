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

  /// `POST /quests/weekly/ai`
  ///
  /// 사용자가 고른 AI 추천 후보를 이번 주 주간 슬롯에 넣는다. 후보 내용이 아니라
  /// id만 보낸다 — 내용을 보내면 제목·완료 가이드를 앱에서 바꿔 보낼 수 있다.
  ///
  /// 주당 한 번이며 이미 받았으면 서버가 409(`WEEKLY_AI_QUEST_ALREADY_CLAIMED`)를 준다.
  Future<DailyQuest> claimWeeklyAiQuest(int candidateId) => _guard(() async {
    final response = await _dio.post<dynamic>(
      '/quests/weekly/ai',
      data: {'candidateId': candidateId},
    );
    return DailyQuest.fromJson(asMap(response.data));
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
  /// 좌표는 `completion_type = LOCATION`인 퀘스트에만 싣는다.
  /// SELF_REPORT는 본문 없이 호출한다(`04-api-spec.md` §4).
  ///
  /// 좌표를 [CompletionCoordinates] 한 덩어리로 받아, 위경도·정확도 중
  /// 일부만 채워진 요청이 조용히 SELF_REPORT처럼 나가는 일을 막는다.
  Future<QuestCompletionResult> complete(
    int dailyQuestId, {
    CompletionCoordinates? coordinates,
  }) => _guard(() async {
    final response = await _dio.post<dynamic>(
      '/daily-quests/$dailyQuestId/complete',
      data: coordinates?.toJson(),
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
