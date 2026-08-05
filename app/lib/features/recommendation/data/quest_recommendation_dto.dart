import 'package:life_quest/shared/data/json_reader.dart';

enum RecommendationType { place, travel }

enum RecommendationEnvironment { indoor, outdoor, any }

class QuestRecommendationCandidate {
  const QuestRecommendationCandidate({
    required this.index,
    required this.type,
    required this.title,
    required this.description,
    required this.category,
    required this.durationValue,
    required this.durationUnit,
    required this.estimatedCostPerPerson,
    required this.suggestedPlaceName,
    required this.completionGuide,
  });
  final int index, durationValue, estimatedCostPerPerson;
  final RecommendationType type;
  final String title,
      description,
      category,
      durationUnit,
      suggestedPlaceName,
      completionGuide;
  factory QuestRecommendationCandidate.fromJson(Map<String, dynamic> j) =>
      QuestRecommendationCandidate(
        index: asInt(j['index']) ?? 0,
        type: asString(j['recommendationType']) == 'TRAVEL'
            ? RecommendationType.travel
            : RecommendationType.place,
        title: asString(j['title']) ?? '추천 퀘스트',
        description: asString(j['description']) ?? '',
        category: asString(j['category']) ?? 'EXPERIENCE',
        durationValue: asInt(j['durationValue']) ?? 0,
        durationUnit: asString(j['durationUnit']) ?? '',
        estimatedCostPerPerson: asInt(j['estimatedCostPerPerson']) ?? 0,
        suggestedPlaceName: asString(j['suggestedPlaceName']) ?? '',
        completionGuide: asString(j['completionGuide']) ?? '',
      );
}

class QuestRecommendationResult {
  const QuestRecommendationResult({
    required this.provider,
    required this.model,
    required this.remainingRequestsToday,
    required this.candidates,
  });
  final String provider, model;
  final int remainingRequestsToday;
  final List<QuestRecommendationCandidate> candidates;
  factory QuestRecommendationResult.fromJson(Object? body) {
    final j = asMap(body);
    return QuestRecommendationResult(
      provider: asString(j['provider']) ?? '',
      model: asString(j['model']) ?? '',
      remainingRequestsToday: asInt(j['remainingRequestsToday']) ?? 0,
      candidates: asMapList(
        j['candidates'],
      ).map(QuestRecommendationCandidate.fromJson).toList(),
    );
  }
}
