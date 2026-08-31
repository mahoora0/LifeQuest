import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/presentation/widgets/quest_rows.dart';

/// 홈 행이 주간 배정을 주간이라고 말하는지 고정한다.
///
/// 홈 카드는 `GET /quests/today`가 주는 것을 필터 없이 전부 그린다. 그 응답은
/// 설계상 두 트랙을 평평한 `quests[]`로 주므로(일간 3 + 주간 자동 2), 카드가
/// `오늘의 퀘스트 0 / 5`를 띄우는 동안 그중 둘은 이번 주 것이다. 행에 구분이
/// 없으면 화면만 보고는 "오늘 할 일이 다섯"으로 읽힌다.
///
/// 세는 값이 아니라 **행의 표시**를 재는 이유는 5라는 수가 결함이 아니기
/// 때문이다 — 응답이 두 트랙을 함께 주는 것은 계약이고, 탭으로 가르는 일은
/// 목록 화면(S-08)의 몫이다.
void main() {
  Quest quest({required QuestCadence cadence}) => Quest(
    id: 1,
    title: '한강에서 노을 보기',
    completionType: QuestCompletionType.selfReport,
    expReward: 30,
    cadence: cadence,
  );

  Widget host(QuestCadence cadence) => MaterialApp(
    home: Scaffold(
      body: HomeQuestRow(
        dailyQuest: DailyQuest(
          dailyQuestId: 1,
          status: DailyQuestStatus.assigned,
          quest: quest(cadence: cadence),
        ),
        onTap: () {},
        onCheck: () {},
      ),
    ),
  );

  testWidgets('주간 배정에는 주기 뱃지가 붙는다', (tester) async {
    await tester.pumpWidget(host(QuestCadence.weekly));

    expect(find.text('주간'), findsOneWidget);
  });

  /// 카드 제목 띠가 이미 `오늘의 퀘스트`라 일간 뱃지는 정보를 더하지 않는다.
  /// 모든 행에 하나씩 늘어나면 좁은 홈 행에서 제목이 밀린다.
  testWidgets('일간 배정에는 주기 뱃지를 붙이지 않는다', (tester) async {
    await tester.pumpWidget(host(QuestCadence.daily));

    expect(find.text('일간'), findsNothing);
    expect(find.text('주간'), findsNothing);
  });
}
