import 'package:life_quest/shared/data/json_reader.dart';

enum RecommendationType { place, travel }

enum RecommendationEnvironment { indoor, outdoor, any }

class QuestRecommendationCandidate {
  const QuestRecommendationCandidate({
    required this.index,
    this.candidateId,
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

  /// 서버가 보관 중인 후보 id. **주간 추천에서만 채워진다** — 일반 place/travel
  /// 추천은 후보를 저장하지 않으므로 null이다.
  ///
  /// 선택 요청은 후보 내용이 아니라 이 id만 보낸다. 내용을 되돌려 보내면
  /// 제목·완료 가이드를 앱에서 바꿔 보낼 수 있어 서버 검증이 무의미해진다.
  final int? candidateId;

  /// 주간 퀘스트로 받을 수 있는 후보인가.
  bool get isClaimable => candidateId != null;
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
        candidateId: asInt(j['candidateId']),
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
