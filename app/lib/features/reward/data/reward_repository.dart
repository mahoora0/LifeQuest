import 'package:life_quest/features/reward/data/reward_dto.dart';
import 'package:life_quest/shared/data/sample_data.dart';

/// 레벨 · 보상 조회.
///
/// ⚠ **서버 미구현 구간이다.** `GET /api/users/me/rewards`가 아직 없다. 표본은
/// 시안(`LifeQuest 화면맵` 2c)의 예시를 옮긴 것으로 실제 사용자 데이터가 아니며,
/// [LqSampleData.guard] 때문에 **릴리스 빌드에서는 나오지 않는다**(준비 중 안내로 떨어진다).
///
// TODO(server): GET /api/users/me/rewards 개설 시 fetchOverview 본문을 Dio 호출로
//  바꾸고 LqSampleData.guard 호출과 표본 상수를 지운다.
// TODO(server): questsToNextLevel(남은 EXP ÷ 평균 퀘스트 보상)은 서버 계산값이다.
//  응답에 없으면 화면이 해당 문구를 감춘다 — 클라이언트에서 추정하지 않는다.
class RewardRepository {
  const RewardRepository();

  Future<RewardOverview> fetchOverview() async {
    LqSampleData.guard('레벨 · 보상');
    return const RewardOverview(
      level: 12,
      exp: 840,
      expForNextLevel: 1200,
      questsToNextLevel: 9,
      nextMilestone: LevelMilestone(
        level: 13,
        rewardLine: 'Lv.13 · 칭호 "길잡이"',
        currencyLine: '골드 200 · 보석 5',
      ),
      received: [
        ReceivedReward(
          level: 12,
          name: '성실한 모험가',
          kind: LqRewardKind.title,
          timeLabel: '어제',
        ),
        ReceivedReward(
          level: 12,
          name: '은빛 나침반',
          kind: LqRewardKind.item,
          timeLabel: '3일 전',
          note: 'Lv.12 달성',
        ),
        ReceivedReward(
          level: 10,
          name: '개척자의 깃발',
          kind: LqRewardKind.badge,
          timeLabel: '2주 전',
          note: 'Lv.10 달성',
        ),
        ReceivedReward(
          level: 5,
          name: '첫 걸음',
          kind: LqRewardKind.title,
          timeLabel: '지난달',
          note: 'Lv.5 달성',
        ),
      ],
      weeklyExp: [
        DailyExp(dayLabel: '월', exp: 80),
        DailyExp(dayLabel: '화', exp: 130),
        DailyExp(dayLabel: '수', exp: 60),
        DailyExp(dayLabel: '목', exp: 150),
        DailyExp(dayLabel: '금', exp: 110),
        DailyExp(dayLabel: '토', exp: 190),
        DailyExp(dayLabel: '일', exp: 70),
      ],
    );
  }
}
