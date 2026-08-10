import 'package:life_quest/shared/data/json_reader.dart';

/// 받은 보상의 갈래. 화면에서 "칭호 · 어제"처럼 시점과 붙여 적는다.
enum LqRewardKind {
  title('칭호'),
  item('아이템'),
  currency('재화');

  const LqRewardKind(this.label);

  final String label;

  static LqRewardKind parse(String? raw) => switch (raw) {
    'ITEM' || 'item' => item,
    'CURRENCY' || 'currency' => currency,
    _ => title,
  };
}

/// 레벨 달성으로 받은 보상 한 줄.
class ReceivedReward {
  const ReceivedReward({
    required this.level,
    required this.name,
    required this.kind,
    required this.timeLabel,
    this.note,
  });

  /// 이 보상을 받은 레벨. 행 앞머리 원형 표식에 그대로 찍는다.
  final int level;
  final String name;
  final LqRewardKind kind;

  /// "어제", "3일 전"처럼 서버가 사람이 읽을 형태로 준 시점.
  final String timeLabel;

  /// "Lv.12 달성" 같은 획득 계기. 없으면 시점만 적는다.
  final String? note;

  factory ReceivedReward.fromJson(Map<String, dynamic> json) => ReceivedReward(
    level: asInt(json['level']) ?? 0,
    name: asString(pick(json, ['name', 'title'])) ?? '',
    kind: LqRewardKind.parse(asString(pick(json, ['kind', 'type']))),
    timeLabel: asString(pick(json, ['timeLabel', 'displayTime'])) ?? '',
    note: asString(pick(json, ['note', 'reason'])),
  );
}

/// 다음 관문 — 아직 닿지 않은 레벨과 거기 걸린 보상.
class LevelMilestone {
  const LevelMilestone({
    required this.level,
    required this.rewardLine,
    this.currencyLine,
  });

  final int level;

  /// "Lv.13 · 칭호 \"길잡이\"" 처럼 한 줄로 정리된 보상 설명.
  final String rewardLine;

  /// "골드 200 · 보석 5". 재화 개념이 서버에 없으므로 `LqFeatures.currencyEnabled`가
  /// 켜질 때까지 화면에서 감춘다.
  final String? currencyLine;

  factory LevelMilestone.fromJson(Map<String, dynamic> json) => LevelMilestone(
    level: asInt(json['level']) ?? 0,
    rewardLine: asString(pick(json, ['rewardLine', 'description'])) ?? '',
    currencyLine: asString(pick(json, ['currencyLine', 'currency'])),
  );
}

/// 요일별 획득 EXP 한 칸.
class DailyExp {
  const DailyExp({required this.dayLabel, required this.exp});

  final String dayLabel;
  final int exp;

  factory DailyExp.fromJson(Map<String, dynamic> json) => DailyExp(
    dayLabel: asString(pick(json, ['dayLabel', 'day'])) ?? '',
    exp: asInt(json['exp']) ?? 0,
  );
}

/// S-05 레벨 · 보상 화면이 한 번에 필요로 하는 값 묶음 (`GET /api/users/me/rewards`).
class RewardOverview {
  const RewardOverview({
    required this.level,
    required this.exp,
    required this.expForNextLevel,
    this.questsToNextLevel,
    this.nextMilestone,
    this.received = const [],
    this.weeklyExp = const [],
  });

  final int level;
  final int exp;
  final int expForNextLevel;

  /// "퀘스트 9개면 다음 레벨이에요" 문구의 근거.
  ///
  /// 남은 EXP를 평균 퀘스트 보상으로 나눈 값이라 서버가 계산해야 한다.
  /// 주지 않으면 문구를 감춘다 — 클라이언트가 평균을 추측하면 실제와 어긋난다.
  final int? questsToNextLevel;

  final LevelMilestone? nextMilestone;
  final List<ReceivedReward> received;
  final List<DailyExp> weeklyExp;

  int get expToNext => (expForNextLevel - exp).clamp(0, expForNextLevel);

  bool get isEmpty => received.isEmpty && nextMilestone == null;

  factory RewardOverview.fromJson(Object? body) {
    final json = asMap(body);
    final milestone = pick(json, ['nextMilestone', 'next']);

    return RewardOverview(
      level: asInt(json['level']) ?? 1,
      exp: asInt(pick(json, ['exp', 'currentExp'])) ?? 0,
      expForNextLevel:
          asInt(pick(json, ['expForNextLevel', 'nextLevelExp'])) ?? 100,
      questsToNextLevel: asInt(pick(json, ['questsToNextLevel', 'questsLeft'])),
      nextMilestone: milestone is Map
          ? LevelMilestone.fromJson(asMap(milestone))
          : null,
      received: asMapList(
        pick(json, ['received', 'rewards']),
      ).map(ReceivedReward.fromJson).toList(),
      weeklyExp: asMapList(
        pick(json, ['weeklyExp', 'weekly']),
      ).map(DailyExp.fromJson).toList(),
    );
  }
}
