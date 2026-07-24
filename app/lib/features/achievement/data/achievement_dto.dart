import 'package:life_quest/shared/data/json_reader.dart';

/// 업적 1건.
///
/// 비밀 업적은 미달성 시 서버가 이름·조건을 마스킹해서 내려준다.
/// 클라이언트는 마스킹 값을 그대로 표시하고 별도 복원을 시도하지 않는다.
class Achievement {
  const Achievement({
    required this.id,
    required this.name,
    required this.achieved,
    required this.secret,
    this.condition,
    this.currentValue,
    this.requiredValue,
    this.currentStep,
    this.expReward,
  });

  final int id;
  final String name;
  final bool achieved;
  final bool secret;
  final String? condition;
  final int? currentValue;
  final int? requiredValue;

  /// 단계형 업적의 현재 단계.
  final int? currentStep;
  final int? expReward;

  /// 비밀 업적이면서 아직 달성하지 못한 상태 — 점선 잠김 행으로 표시한다.
  bool get isHiddenSecret => secret && !achieved;

  bool get hasProgress =>
      !achieved &&
      currentValue != null &&
      requiredValue != null &&
      requiredValue! > 0;

  double get progressRatio =>
      hasProgress ? (currentValue! / requiredValue!).clamp(0, 1).toDouble() : 0;

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    id: asInt(pick(json, ['id', 'achievementId'])) ?? 0,
    name: asString(pick(json, ['name', 'title'])) ?? '업적',
    achieved: asBool(pick(json, ['achieved', 'completed', 'isAchieved'])),
    secret: asBool(pick(json, ['secret', 'isSecret', 'hidden'])),
    condition: asString(
      pick(json, ['condition', 'conditionText', 'description']),
    ),
    currentValue: asInt(pick(json, ['currentValue', 'current', 'progress'])),
    requiredValue: asInt(
      pick(json, ['requiredValue', 'required', 'targetValue', 'goal']),
    ),
    currentStep: asInt(pick(json, ['currentStep', 'current_step', 'step'])),
    expReward: asInt(pick(json, ['expReward', 'exp'])),
  );

  /// 카탈로그(`/achievements`)에 내 현황(`/users/me/achievements`)을 덮어쓴다.
  ///
  /// 비밀 업적은 **미달성 동안만** 카탈로그에서 마스킹된다. 달성 기록이 있으면
  /// 내 현황이 실제 이름·조건을 갖고 있으므로 그쪽을 정본으로 삼는다.
  /// 카탈로그를 우선하면 "완료" 도장 옆에 마스킹된 이름이 남는다.
  Achievement mergeWith(Achievement mine) {
    final preferMine = mine.achieved;
    return Achievement(
      id: id,
      name: preferMine && mine.name.isNotEmpty ? mine.name : name,
      achieved: mine.achieved || achieved,
      secret: secret,
      condition: preferMine
          ? (mine.condition ?? condition)
          : (condition ?? mine.condition),
      currentValue: mine.currentValue ?? currentValue,
      requiredValue: mine.requiredValue ?? requiredValue,
      currentStep: mine.currentStep ?? currentStep,
      expReward: expReward ?? mine.expReward,
    );
  }
}

/// 업적 탭이 쓰는 통합 뷰 모델.
class AchievementOverview {
  const AchievementOverview({required this.achievements});

  final List<Achievement> achievements;

  int get total => achievements.length;
  int get achievedCount => achievements.where((a) => a.achieved).length;
  bool get isEmpty => achievements.isEmpty;
}

/// 업적 필터(07 명세 §6-④ 제안값).
enum AchievementFilter {
  all('전체'),
  achieved('달성'),
  inProgress('진행 중'),
  secret('비밀');

  const AchievementFilter(this.label);

  final String label;

  bool matches(Achievement achievement) => switch (this) {
    AchievementFilter.all => true,
    AchievementFilter.achieved => achievement.achieved,
    AchievementFilter.inProgress => !achievement.achieved,
    AchievementFilter.secret => achievement.secret,
  };
}
