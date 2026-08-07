import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/presentation/quest_result_screen.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
import 'package:life_quest/features/user/data/user_dto.dart';

void main() {
  testWidgets('레벨 3 달성 시 주간 퀘스트 해금을 보여준다', (tester) async {
    await tester.pumpWidget(_app(_result(2, 3)));
    await tester.pump();
    await tester.pump();

    expect(find.text('LEVEL UP!'), findsOneWidget);
    expect(find.text('주간 퀘스트'), findsWidgets);
    expect(find.text('협동 퀘스트'), findsNothing);
  });

  testWidgets('여러 레벨을 건너뛰면 사이에 해금된 기능을 모두 보여준다', (tester) async {
    await tester.pumpWidget(_app(_result(2, 5)));
    await tester.pump();
    await tester.pump();

    expect(find.text('주간 퀘스트'), findsWidgets);
    expect(find.text('협동 퀘스트'), findsWidgets);
  });

  testWidgets('레벨 5 달성 시 새 캐릭터를 보여준다', (tester) async {
    await tester.pumpWidget(_app(_result(4, 5)));
    await tester.pump();
    await tester.pump();

    expect(find.text('모각'), findsOneWidget);
    expect(find.text('새 캐릭터 해금'), findsOneWidget);
  });

  testWidgets('레벨 4 달성 시 레벨업 모달과 새 액세서리를 보여준다', (tester) async {
    await tester.pumpWidget(_app(_result(3, 4)));
    await tester.pump();
    await tester.pump();

    expect(find.text('LEVEL UP!'), findsOneWidget);
    expect(find.text('Lv.4'), findsWidgets);
    expect(find.text('탐험가 모자'), findsOneWidget);
    expect(find.text('새 액세서리 해금'), findsOneWidget);
  });
}

Widget _app(QuestCompletionResult result) => ProviderScope(
  overrides: [
    characterCollectionProvider.overrideWith(
      (ref) async => const [
        AvatarCharacter(
          id: 1,
          code: 'ROOKIE',
          name: '루키',
          assetKey: 'rookie.png',
        ),
        AvatarCharacter(
          id: 2,
          code: 'MOGAK',
          name: '모각',
          assetKey: 'mogak.png',
          requiredLevel: 5,
        ),
      ],
    ),
    accessoryCollectionProvider.overrideWith(
      (ref) async => const AccessoryCollection(
        accessories: [
          AvatarAccessory(id: 4, code: 'APRON', name: '앞치마', requiredLevel: 2),
          AvatarAccessory(
            id: 5,
            code: 'EXPLORER_HAT',
            name: '탐험가 모자',
            requiredLevel: 4,
          ),
        ],
        selectedAccessoryId: null,
      ),
    ),
  ],
  child: MaterialApp(home: QuestResultScreen(result: result)),
);

QuestCompletionResult _result(int previousLevel, int currentLevel) =>
    QuestCompletionResult(
      completionId: 1,
      dailyQuestId: 1,
      questId: 1,
      duplicated: false,
      questTitle: '테스트 퀘스트',
      growth: GrowthResult(
        expGained: 100,
        totalExp: 300,
        previousLevel: previousLevel,
        currentLevel: currentLevel,
        levelUp: true,
        rewards: const [],
      ),
      collection: CollectionResult.empty,
    );
