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
