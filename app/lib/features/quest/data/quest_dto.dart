import 'package:life_quest/shared/data/json_reader.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 완료 방식 (`QUESTS.completion_type`).
enum QuestCompletionType {
  selfReport,
  location;

  static QuestCompletionType parse(Object? raw) {
    final value = asString(raw)?.toUpperCase();
    return value == 'LOCATION'
        ? QuestCompletionType.location
        : QuestCompletionType.selfReport;
  }

  bool get isLocation => this == QuestCompletionType.location;

  LqTagPalette get palette =>
      isLocation ? LqTagPalette.location : LqTagPalette.selfReport;
}

/// 배정 상태 (`USER_DAILY_QUESTS.status`).
enum DailyQuestStatus {
  assigned,
  completed,
  expired;

  static DailyQuestStatus parse(Object? raw) {
    return switch (asString(raw)?.toUpperCase()) {
      'COMPLETED' || 'DONE' => DailyQuestStatus.completed,
      'EXPIRED' => DailyQuestStatus.expired,
      _ => DailyQuestStatus.assigned,
    };
  }

  bool get isCompleted => this == DailyQuestStatus.completed;
  bool get isExpired => this == DailyQuestStatus.expired;
}

/// 퀘스트 마스터 정보.
class Quest {
  const Quest({
    required this.id,
    required this.title,
    required this.completionType,
    required this.expReward,
    this.description,
    this.grade,
    this.placeName,
    this.latitude,
    this.longitude,
    this.radiusM,
  });

  final int id;
  final String title;
  final String? description;
  final String? grade;
  final QuestCompletionType completionType;
  final int expReward;
  final String? placeName;
  final double? latitude;
  final double? longitude;
  final int? radiusM;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// 인증 반경(m). 서버가 값을 주지 않으면 안내용 기본값 50m.
  int get effectiveRadiusM => radiusM ?? 50;

  factory Quest.fromJson(Map<String, dynamic> json, {int? idOverride}) {
    return Quest(
      id: idOverride ?? asInt(pick(json, ['questId', 'id'])) ?? 0,
      title: asString(pick(json, ['title', 'questTitle', 'name'])) ?? '퀘스트',
      description: asString(pick(json, ['description', 'questDescription'])),
      grade: asString(json['grade']),
      completionType: QuestCompletionType.parse(
        pick(json, ['completionType', 'completion_type', 'type']),
      ),
      expReward: asInt(pick(json, ['expReward', 'exp', 'expAmount'])) ?? 0,
      placeName: asString(pick(json, ['placeName', 'place_name', 'place'])),
      latitude: asDouble(pick(json, ['latitude', 'lat'])),
      longitude: asDouble(pick(json, ['longitude', 'lng', 'lon'])),
      radiusM: asInt(pick(json, ['radiusM', 'radius_m', 'radius'])),
    );
  }
}

/// 오늘 배정된 퀘스트 1건(배정 정보 + 퀘스트 요약).
class DailyQuest {
  const DailyQuest({
    required this.dailyQuestId,
    required this.status,
    required this.quest,
    this.distanceM,
  });

  final int dailyQuestId;
  final DailyQuestStatus status;
  final Quest quest;

  /// `GET /quests/nearby` 응답에만 담기는 현재 위치 기준 거리.
  final double? distanceM;

  int get questId => quest.id;

  factory DailyQuest.fromJson(Map<String, dynamic> json) {
    // 서버가 퀘스트 요약을 중첩(`quest`)으로 줄 수도, 평탄화해서 줄 수도 있다.
    final nested = asMap(pick(json, ['quest', 'questSummary']));
    final merged = <String, dynamic>{...json, ...nested};
    final questId =
        asInt(pick(json, ['questId'])) ?? asInt(nested['id']) ?? 0;

    return DailyQuest(
      dailyQuestId:
          asInt(pick(json, ['dailyQuestId', 'userDailyQuestId', 'id'])) ?? 0,
      status: DailyQuestStatus.parse(pick(json, ['status', 'assignmentStatus'])),
      quest: Quest.fromJson(merged, idOverride: questId),
      distanceM: asDouble(pick(json, ['distanceM', 'distance'])),
    );
  }
}

/// `GET /quests/today` 응답.
class TodayQuests {
  const TodayQuests({required this.assignedDate, required this.quests});

  final String? assignedDate;
  final List<DailyQuest> quests;

  int get total => quests.length;
  int get completedCount => quests.where((q) => q.status.isCompleted).length;
  bool get isEmpty => quests.isEmpty;

  factory TodayQuests.fromJson(Object? body) {
    final json = asMap(body);
    return TodayQuests(
      assignedDate: asString(json['assignedDate']),
      quests: asMapList(pick(json, ['quests', 'content', 'items']))
          .map(DailyQuest.fromJson)
          .toList(),
    );
  }
}

/// 완료 응답에 담기는 위치 판정 결과 (`completion_type = LOCATION`일 때만).
class CompletionLocation {
  const CompletionLocation({this.distanceM, this.accuracyM});

  final double? distanceM;
  final double? accuracyM;

  factory CompletionLocation.fromJson(Map<String, dynamic> json) =>
      CompletionLocation(
        distanceM: asDouble(json['distanceM']),
        accuracyM: asDouble(json['accuracyM']),
      );
}

/// 레벨업 보상 1건.
class GrowthReward {
  const GrowthReward({required this.type, required this.name, this.code});

  final String type;
  final String name;
  final String? code;

  bool get isTitle => type.toUpperCase() == 'TITLE';

  factory GrowthReward.fromJson(Map<String, dynamic> json) => GrowthReward(
    type: asString(json['type']) ?? 'ITEM',
    name: asString(pick(json, ['name', 'code'])) ?? '보상',
    code: asString(json['code']),
  );
}

/// 완료 응답의 성장(EXP·레벨) 결과.
class GrowthResult {
  const GrowthResult({
    required this.expGained,
    required this.totalExp,
    required this.previousLevel,
    required this.currentLevel,
    required this.levelUp,
    required this.rewards,
  });

  final int expGained;
  final int totalExp;
  final int previousLevel;
  final int currentLevel;
  final bool levelUp;
  final List<GrowthReward> rewards;

  factory GrowthResult.fromJson(Map<String, dynamic> json) => GrowthResult(
    expGained: asInt(json['expGained']) ?? 0,
    totalExp: asInt(json['totalExp']) ?? 0,
    previousLevel: asInt(json['previousLevel']) ?? 0,
    currentLevel: asInt(json['currentLevel']) ?? 0,
    levelUp: asBool(json['levelUp']),
    rewards: asMapList(json['rewards']).map(GrowthReward.fromJson).toList(),
  );

  static const empty = GrowthResult(
    expGained: 0,
    totalExp: 0,
    previousLevel: 0,
    currentLevel: 0,
    levelUp: false,
    rewards: [],
  );
}

/// 신규 도감·업적 항목.
class CollectionEntry {
  const CollectionEntry({required this.name, this.id});

  final String name;
  final int? id;

  factory CollectionEntry.fromJson(Map<String, dynamic> json) =>
      CollectionEntry(
        id: asInt(json['id']),
        name: asString(json['name']) ?? '새 항목',
      );
}

class CollectionResult {
  const CollectionResult({
    required this.newLifedexItems,
    required this.newAchievements,
  });

  final List<CollectionEntry> newLifedexItems;
  final List<CollectionEntry> newAchievements;

  bool get isEmpty => newLifedexItems.isEmpty && newAchievements.isEmpty;

  factory CollectionResult.fromJson(Map<String, dynamic> json) =>
      CollectionResult(
        newLifedexItems: asMapList(
          json['newLifedexItems'],
        ).map(CollectionEntry.fromJson).toList(),
        newAchievements: asMapList(
          json['newAchievements'],
        ).map(CollectionEntry.fromJson).toList(),
      );

  static const empty = CollectionResult(
    newLifedexItems: [],
    newAchievements: [],
  );
}

/// `POST /daily-quests/{id}/complete` 통합 응답.
class QuestCompletionResult {
  const QuestCompletionResult({
    required this.completionId,
    required this.dailyQuestId,
    required this.questId,
    required this.duplicated,
    required this.growth,
    required this.collection,
    this.questTitle,
    this.grade,
    this.completedAt,
    this.location,
  });

  final int completionId;
  final int dailyQuestId;
  final int questId;

  /// 멱등 재요청 — 보상 재지급 없이 기존 완료 결과가 그대로 온다.
  final bool duplicated;
  final GrowthResult growth;
  final CollectionResult collection;

  /// 응답에는 없지만 결과 화면 표시용으로 클라이언트가 채워 넣는 값.
  final String? questTitle;
  final String? grade;
  final String? completedAt;
  final CompletionLocation? location;

  factory QuestCompletionResult.fromJson(Object? body) {
    final json = asMap(body);
    final location = json['location'];
    return QuestCompletionResult(
      completionId: asInt(json['completionId']) ?? 0,
      dailyQuestId: asInt(json['dailyQuestId']) ?? 0,
      questId: asInt(json['questId']) ?? 0,
      duplicated: asBool(json['duplicated']),
      grade: asString(json['grade']),
      completedAt: asString(json['completedAt']),
      location: location is Map
          ? CompletionLocation.fromJson(Map<String, dynamic>.from(location))
          : null,
      growth: json['growth'] is Map
          ? GrowthResult.fromJson(asMap(json['growth']))
          : GrowthResult.empty,
      collection: json['collection'] is Map
          ? CollectionResult.fromJson(asMap(json['collection']))
          : CollectionResult.empty,
    );
  }

  QuestCompletionResult withQuestTitle(String? title) =>
      QuestCompletionResult(
        completionId: completionId,
        dailyQuestId: dailyQuestId,
        questId: questId,
        duplicated: duplicated,
        growth: growth,
        collection: collection,
        questTitle: title ?? questTitle,
        grade: grade,
        completedAt: completedAt,
        location: location,
      );
}
