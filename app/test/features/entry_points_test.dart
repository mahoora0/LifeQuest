import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/lifedex/application/lifedex_providers.dart';
import 'package:life_quest/features/lifedex/data/lifedex_dto.dart';
import 'package:life_quest/features/lifedex/data/lifedex_repository.dart';
import 'package:life_quest/features/lifedex/presentation/lifedex_screen.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/data/quest_repository.dart';
import 'package:life_quest/features/quest/presentation/quest_list_screen.dart';

/// 진입점 점검(시안 "화면 구성 규칙" §10).
///
/// 눌러도 아무 일이 없는 요소는 "고장"으로 읽힌다. 연결하거나 지운 결과를 고정한다.
void main() {
  testWidgets('퀘스트 목록 헤더에 검색을 두지 않는다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questRepositoryProvider.overrideWithValue(_EmptyQuestRepository()),
        ],
        child: const MaterialApp(home: QuestListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('퀘스트 목록'), findsOneWidget);
    // 목록이 3~8개인 화면에 검색이 있으면 데이터가 더 많아 보이는 오해를 준다.
    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.bySemanticsLabel('검색'), findsNothing);
  });

  testWidgets('LifeDex 헤더에서 업적으로 건너가는 문을 두지 않는다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lifedexRepositoryProvider.overrideWithValue(
            _EmptyLifedexRepository(),
          ),
        ],
        child: const MaterialApp(home: LifedexScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('도감'), findsOneWidget);
    // 도감과 업적은 형제가 아니라 둘 다 마이페이지 하위라 계층을 흐린다.
    expect(find.byIcon(Icons.emoji_events_outlined), findsNothing);
    expect(find.bySemanticsLabel('업적'), findsNothing);
    // 탭 밖 push 화면이므로 돌아갈 길은 남아야 한다.
    expect(find.bySemanticsLabel('뒤로 가기'), findsOneWidget);
  });
}

class _EmptyQuestRepository extends QuestRepository {
  _EmptyQuestRepository() : super(Dio());

  @override
  Future<TodayQuests> fetchToday() async =>
      const TodayQuests(assignedDate: null, quests: []);
}

class _EmptyLifedexRepository extends LifedexRepository {
  _EmptyLifedexRepository() : super(Dio());

  @override
  Future<LifedexOverview> fetchOverview() async =>
      const LifedexOverview(categories: []);
}
