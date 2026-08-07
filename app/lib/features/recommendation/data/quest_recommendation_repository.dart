import 'package:dio/dio.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/recommendation/data/quest_recommendation_dto.dart';

class QuestRecommendationRepository {
  const QuestRecommendationRepository(this._dio);
  final Dio _dio;
  Future<QuestRecommendationResult> place(Map<String, dynamic> data) =>
      _post('/quest-recommendations/place', data);
  Future<QuestRecommendationResult> travel(Map<String, dynamic> data) =>
      _post('/quest-recommendations/travel', data);

  /// 주간 퀘스트용 추천. 일반 추천과 경로가 다르다 — Lv.3 잠금과 그 주의 남은
  /// 기간 제한이 여기에만 걸리고, 후보도 이쪽에서만 저장된다.
  Future<QuestRecommendationResult> weeklyPlace(Map<String, dynamic> data) =>
      _post('/quest-recommendations/weekly/place', data);
  Future<QuestRecommendationResult> weeklyTravel(Map<String, dynamic> data) =>
      _post('/quest-recommendations/weekly/travel', data);
  Future<QuestRecommendationResult> _post(
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      return QuestRecommendationResult.fromJson(
        (await _dio.post<dynamic>(
          path,
          data: data,
          options: Options(
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 35),
          ),
        )).data,
      );
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }
}
