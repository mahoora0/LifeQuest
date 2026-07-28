import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/reward/application/reward_providers.dart';
import 'package:life_quest/features/reward/data/reward_dto.dart';
import 'package:life_quest/features/reward/data/reward_repository.dart';
import 'package:life_quest/features/reward/presentation/reward_screen.dart';

/// S-05 레벨 · 보상. 서버가 주지 않는 값을 추측해서 표시하지 않는 것이 이 화면의 규칙이다.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpRewards(
    WidgetTester tester,
    RewardRepository repository,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rewardRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: RewardScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('레벨·남은 EXP·받은 보상을 함께 보여준다', (tester) async {
    await pumpRewards(tester, const _FakeRewardRepository());

    expect(find.text('레벨 · 보상'), findsOneWidget);
    expect(find.text('Lv. 12'), findsOneWidget);
    expect(find.text('다음 관문'), findsOneWidget);
    expect(find.text('Lv.13 · 칭호 "길잡이"'), findsOneWidget);
    expect(find.text('잠김'), findsOneWidget);

    expect(find.text('받은 보상'), findsOneWidget);
    expect(find.text('성실한 모험가'), findsOneWidget);
    expect(find.text('칭호 · 어제'), findsOneWidget);
    expect(find.text('은빛 나침반'), findsOneWidget);
    expect(find.text('아이템 · 3일 전 · Lv.12 달성'), findsOneWidget);
  });

  testWidgets('남은 퀘스트 수는 서버가 줄 때만 문구로 보여준다', (tester) async {
    await pumpRewards(tester, const _FakeRewardRepository());
    expect(find.text('퀘스트 9개면 다음 레벨이에요'), findsOneWidget);
  });

  testWidgets('남은 퀘스트 수가 없으면 평균을 추측해 만들어내지 않는다', (tester) async {
    await pumpRewards(tester, const _NoEstimateRewardRepository());

    expect(find.text('Lv. 12'), findsOneWidget);
    expect(find.textContaining('개면 다음 레벨이에요'), findsNothing);
  });

  testWidgets('재화가 서버에 없는 동안 골드·보석 줄을 감춘다', (tester) async {
    await pumpRewards(tester, const _FakeRewardRepository());

    // LqFeatures.currencyEnabled가 꺼져 있으면 레이아웃은 그대로 두고 노출만 막는다.
    expect(find.text('Lv.13 · 칭호 "길잡이"'), findsOneWidget);
    expect(find.text('골드 200 · 보석 5'), findsNothing);
  });

  testWidgets('서버 구간이 아직 없으면 오류가 아니라 준비 중으로 알린다', (tester) async {
    await pumpRewards(tester, const _NotReadyRewardRepository());

    expect(find.text('레벨 · 보상은 아직 준비 중이에요'), findsOneWidget);
    // 눌러도 결과가 같아 헛돌게 되므로 재시도 버튼을 붙이지 않는다.
    expect(find.text('다시 시도'), findsNothing);
    // 헤더는 본문과 분리되어 남아야 돌아갈 길이 있다.
    expect(find.text('레벨 · 보상'), findsOneWidget);
  });
}

class _FakeRewardRepository extends RewardRepository {
  const _FakeRewardRepository();

  @override
  Future<RewardOverview> fetchOverview() async => const RewardOverview(
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
    ],
    weeklyExp: [
      DailyExp(dayLabel: '월', exp: 80),
      DailyExp(dayLabel: '화', exp: 130),
    ],
  );
}

class _NoEstimateRewardRepository extends RewardRepository {
  const _NoEstimateRewardRepository();

  @override
  Future<RewardOverview> fetchOverview() async =>
      const RewardOverview(level: 12, exp: 840, expForNextLevel: 1200);
}

class _NotReadyRewardRepository extends RewardRepository {
  const _NotReadyRewardRepository();

  @override
  Future<RewardOverview> fetchOverview() async {
    // 미매핑 경로에 백엔드가 붙이는 코드 — `isFeatureNotReady`가 참이 되는 모양이다.
    throw const ApiException(
      code: 'ENDPOINT_NOT_FOUND',
      message: '',
      statusCode: 404,
    );
  }
}
