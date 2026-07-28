import 'package:life_quest/features/reward/data/reward_dto.dart';
import 'package:life_quest/shared/data/sample_data.dart';

/// 레벨 · 보상 조회.
///
/// ⚠ **엔드포인트는 있으나 응답이 이 화면에 모자란다.** `GET /users/me/rewards`는
/// 존재하지만(`UserController.java:109`) `{titles, profileItems}`만 돌려줘서,
/// S-05가 필요한 레벨·다음 관문·획득 시점·주간 EXP가 전부 빠져 있다. 부분만 실데이터로
/// 채우면 어느 수치가 진짜인지 화면에서 구분되지 않으므로 통째로 표본을 쓴다.
///
/// 표본은 시안(`LifeQuest 화면맵` 2c)의 예시이고 실제 사용자 데이터가 아니다.
/// [LqSampleData.guard] 때문에 **릴리스 빌드에서는 나오지 않는다**(준비 중 안내로 떨어진다).
///
/// 호출 경로가 이미 있으므로 응답이 확장되면 [LqSampleData.orSample]로 바꿔 표본이
/// 저절로 물러나게 하는 편이 낫다. 지금은 200이 오지만 필드가 없어 그 방식이 안 통한다.
///
// TODO(server): RewardHistoryResponse에 레벨·다음 관문·획득 시점(acquiredAt)·주간
//  EXP를 더한 뒤, fetchOverview를 UserRepository.fetchRewards와 같은 실호출로 바꾸고
//  표본 상수를 지운다. 지금 응답으로는 "받은 보상" 목록조차 언제 받았는지 알 수 없다.
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
