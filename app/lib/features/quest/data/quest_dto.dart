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

/// 반복 주기 (`QUESTS.cadence`). 배정 트랙을 가르는 기준이다.
///
/// 완료 방식([QuestCompletionType])과는 별개의 축이다 — "새로운 카페 방문하기"처럼
/// 주간이면서 위치 인증인 퀘스트가 있어 한쪽으로 다른 쪽을 유추할 수 없다.
///
/// 협동 탭은 여기 없다. 협동은 시간 주기가 아니라 참여 형태여서 서버도 `cadence`에 담지 않고,
/// 목록 화면의 협동 필터가 `cadence: null`인 것이 그 반영이다.
enum QuestCadence {
  daily('일간'),
  weekly('주간');

  const QuestCadence(this.label);

  final String label;

  /// 모르는 값과 누락은 [daily]로 본다.
  ///
  /// 서버 컬럼의 기본값이 DAILY라 값이 비면 실제로 일간일 가능성이 가장 높고,
  /// 무엇보다 목록에 "전체" 칩이 없어 어느 주기에도 속하지 않는 퀘스트는
  /// 어떤 탭에서도 보이지 않는다. 분류가 애매한 편이 사라지는 것보다 낫다.
  static QuestCadence parse(Object? raw) {
    return switch (asString(raw)?.toUpperCase()) {
      'WEEKLY' => QuestCadence.weekly,
      _ => QuestCadence.daily,
    };
  }

  LqTagPalette get palette => switch (this) {
    QuestCadence.daily => LqTagPalette.daily,
    QuestCadence.weekly => LqTagPalette.weekly,
  };
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

  /// 지금 완료 요청을 보낼 수 있는 상태인가.
  /// 만료 건은 서버가 QUEST_EXPIRED로 거절하므로 UI에서도 막는다.
  bool get isActionable => this == DailyQuestStatus.assigned;
}

/// LOCATION 퀘스트 완료에 실어 보내는 좌표 묶음.
///
/// 세 값을 항상 함께 갖도록 강제한다. 하나라도 빠진 채 요청이 나가면
/// 서버가 LOCATION_REQUIRED로 거절하는데, 그때는 이미 원인을 알기 어렵다.
class CompletionCoordinates {
  const CompletionCoordinates({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  final double latitude;
  final double longitude;
  final double accuracy;

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
  };
}

/// 퀘스트 마스터 정보.
class Quest {
  const Quest({
    required this.id,
    required this.title,
    required this.completionType,
    required this.expReward,
    this.cadence = QuestCadence.daily,
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
  final QuestCadence cadence;
  final QuestCompletionType completionType;
  final int expReward;
  final String? placeName;
  final double? latitude;
  final double? longitude;
  final int? radiusM;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// 서버가 인증 반경을 알려줬는가.
  ///
  /// 값을 임의로 추측하지 않는다. 반경을 모르는 채 클라이언트가 기본값으로
  /// 판정하면 실제로는 인증 가능한 퀘스트를 앱이 영구히 막아버릴 수 있다.
  /// 반경을 모르면 클라이언트 판정을 건너뛰고 서버 판정에 맡긴다.
  bool get hasRadius => radiusM != null;

  factory Quest.fromJson(Map<String, dynamic> json, {int? idOverride}) {
    return Quest(
      id: idOverride ?? asInt(pick(json, ['questId', 'id'])) ?? 0,
      title: asString(pick(json, ['title', 'questTitle', 'name'])) ?? '퀘스트',
      description: asString(pick(json, ['description', 'questDescription'])),
      grade: asString(json['grade']),
      cadence: QuestCadence.parse(pick(json, ['cadence', 'questCadence'])),
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
    // 0은 "못 찾았다"는 뜻이므로 override로 넘기지 않는다.
    // 넘기면 non-null이라 Quest.fromJson의 후보 키 탐색이 통째로 죽는다.
    final questId = asInt(pick(json, ['questId'])) ?? asInt(nested['id']);

    return DailyQuest(
      dailyQuestId:
          asInt(pick(json, ['dailyQuestId', 'userDailyQuestId', 'id'])) ?? 0,
      status: DailyQuestStatus.parse(
        pick(json, ['status', 'assignmentStatus']),
      ),
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

  /// 배정 건 조회. 상세 화면이 `extra`로 받은 스냅샷 대신
  /// 현재 배정 상태를 다시 확인할 때 쓴다.
  DailyQuest? findAssignment({int? dailyQuestId, int? questId}) {
    for (final quest in quests) {
      if (dailyQuestId != null && quest.dailyQuestId == dailyQuestId) {
        return quest;
      }
      if (dailyQuestId == null && questId != null && quest.questId == questId) {
        return quest;
      }
    }
    return null;
  }

  factory TodayQuests.fromJson(Object? body) {
    final json = asMap(body);
    return TodayQuests(
      assignedDate: asString(json['assignedDate']),
      quests: asMapList(
        pick(json, ['quests', 'content', 'items']),
      ).map(DailyQuest.fromJson).toList(),
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
  const CollectionEntry({
    required this.name,
    this.id,
    this.secret = false,
    this.condition,
    this.expReward,
    this.reward,
    this.symbol,
  });

  final String name;
  final int? id;

  /// 비밀 업적인지. 목록에 묻히면 놓치므로 완료 결과 위에 모달로 겹친다.
  final bool secret;

  /// 해금 조건 문장. 비밀 업적은 **해금된 뒤에만** 서버가 내려준다.
  final String? condition;

  final int? expReward;

  /// 함께 받은 보상. 종류·코드까지 담아 칭호와 프로필 아이템을 구분한다 — 이름만으로는
  /// 구분되지 않는다. 계약은 `docs/04-api-spec.md` §4.
  ///
  /// 도감 항목은 보상 개념이 없어 항상 null이고, 업적은 지급 대상이 없거나 지급이 아직
  /// 구현되지 않은 동안 null이다.
  final GrowthReward? reward;

  /// 함께 받은 칭호 이름. 보상이 칭호일 때만 값이 있다.
  String? get titleReward {
    final granted = reward;
    return granted != null && granted.isTitle ? granted.name : null;
  }

  /// 메달에 새길 짧은 글자. 서버가 주지 않으면 이름 첫 글자를 쓴다.
  final String? symbol;

  factory CollectionEntry.fromJson(Map<String, dynamic> json) =>
      CollectionEntry(
        id: asInt(json['id']),
        name: asString(json['name']) ?? '새 항목',
        secret: asBool(pick(json, ['secret', 'isSecret', 'hidden'])),
        condition: asString(pick(json, ['condition', 'conditionText'])),
        expReward: asInt(pick(json, ['expReward', 'exp'])),
        reward: json['reward'] is Map
            ? GrowthReward.fromJson(asMap(json['reward']))
            : null,
        symbol: asString(pick(json, ['symbol', 'icon'])),
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

  /// 비밀 업적 해금분. 목록 한 줄로 알리면 놓치므로 모달로 따로 겹친다(S-17).
  List<CollectionEntry> get newSecretAchievements => [
    for (final entry in newAchievements)
      if (entry.secret) entry,
  ];

  /// 목록에 줄로 알릴 업적 — 비밀 업적은 모달이 맡으므로 뺀다.
  List<CollectionEntry> get newPlainAchievements => [
    for (final entry in newAchievements)
      if (!entry.secret) entry,
  ];

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

  QuestCompletionResult withQuestTitle(String? title) => QuestCompletionResult(
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
