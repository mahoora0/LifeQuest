import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/group/application/group_providers.dart';
import 'package:life_quest/features/group/data/group_dto.dart';
import 'package:life_quest/features/group/data/group_repository.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/data/quest_repository.dart';
import 'package:life_quest/features/quest/presentation/quest_list_screen.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
import 'package:life_quest/features/user/data/user_dto.dart';

import '../support/stub_location_service.dart';

/// 퀘스트 목록(S-08)은 일간·주간·그룹으로 나뉘며 레벨 해금 정책을 따른다.
void main() {
  Future<void> pumpList(WidgetTester tester, {int level = 5}) async {
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          stubLocation,
          questRepositoryProvider.overrideWithValue(_FakeQuestRepository()),
          groupRepositoryProvider.overrideWithValue(_FakeGroupRepository()),
          levelStatusProvider.overrideWith(
            (ref) async => LevelStatus(
              level: level,
              totalExp: 0,
              currentLevelExp: 0,
              nextLevelRequiredExp: 100,
              unlocks: QuestUnlocks(
                weekly: QuestUnlock(level >= 3, 3),
                coop: QuestUnlock(level >= 5, 5),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: QuestListScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('진입 시 일간이 선택되고 "전체" 칩은 없다', (tester) async {
    await pumpList(tester);

    // 일간은 칩 하나와 보이는 두 행의 주기 뱃지로 세 번 잡힌다.
    // 주간·그룹은 해당 행이 걸러졌으므로 칩으로만 잡힌다.
    expect(find.text('일간'), findsNWidgets(3));
    expect(find.text('주간'), findsOneWidget);
    expect(find.text('그룹'), findsOneWidget);
    // "전체"가 없으므로 기본 선택이 반드시 하나 있어야 한다.
    expect(find.text('전체'), findsNothing);

    // AI 추천 진입점은 헤더에서 빠지고 주간 탭의 AI 슬롯 카드만 남는다.
    expect(find.byIcon(Icons.auto_awesome), findsNothing);

    expect(find.text('일간 퀘스트 · 2개'), findsOneWidget);
    expect(find.text('물 여덟 잔 마시기'), findsOneWidget);
    expect(find.text('청계천 물길 따라 걷기'), findsOneWidget);
    expect(find.text('새로운 카페 방문하기'), findsNothing);
    expect(find.text('북한산 백운대 오르기'), findsNothing);
  });

  testWidgets('다른 주기를 고르면 그 주기의 퀘스트만 남는다', (tester) async {
    await pumpList(tester);

    await tester.tap(find.text('주간'));
    await tester.pumpAndSettle();

    expect(find.text('주간 퀘스트 · 1개'), findsOneWidget);
    expect(find.text('새로운 카페 방문하기'), findsOneWidget);
    expect(find.text('물 여덟 잔 마시기'), findsNothing);
  });

  testWidgets('위치 인증 퀘스트는 주기 뱃지와 위치 뱃지를 함께 보여준다', (tester) async {
    await pumpList(tester);

    await tester.tap(find.text('주간'));
    await tester.pumpAndSettle();

    // 목록에 남은 유일한 행이 주간 + 위치다. 칩의 "주간"과 뱃지의 "주간"이 함께 잡힌다.
    expect(find.text('주간'), findsNWidgets(2));
    expect(find.text('위치'), findsOneWidget);
  });

  testWidgets('해금 전 주간 탭은 필요한 레벨을 안내한다', (tester) async {
    await pumpList(tester, level: 1);

    await tester.tap(find.text('주간'));
    await tester.pumpAndSettle();

    expect(find.text('Lv. 3에 열려요'), findsOneWidget);
    expect(find.text('현재 Lv. 1'), findsOneWidget);
  });

  testWidgets('Lv.5 그룹 탭은 내가 속한 그룹 퀘스트를 표시한다', (tester) async {
    await pumpList(tester);

    await tester.tap(find.text('그룹'));
    await tester.pumpAndSettle();

    expect(find.text('그룹 퀘스트 · 1개'), findsOneWidget);
    expect(find.text('한강 공동 산책'), findsOneWidget);
    expect(find.text('주말 탐험대 · 여의도 한강공원'), findsOneWidget);
    expect(find.text('참여 2명 · 8월 9일 19:00'), findsOneWidget);
    expect(find.text('참여 신청 완료'), findsOneWidget);
  });
}

class _FakeGroupRepository extends GroupRepository {
  _FakeGroupRepository() : super(Dio());

  @override
  Future<List<GroupQuest>> myQuests({required bool upcoming}) async => upcoming
      ? [
          GroupQuest(
            id: 41,
            groupId: 7,
            groupName: '주말 탐험대',
            createdByUserId: 1,
            creatorNickname: '그룹장',
            title: '한강 공동 산책',
            description: '함께 걸어요',
            placeName: '여의도 한강공원',
            scheduledAt: DateTime(2026, 8, 9, 19),
            status: GroupQuestStatus.published,
            participantCount: 2,
            myParticipationStatus: GroupQuestParticipationStatus.applied,
          ),
        ]
      : [];
}

class _FakeQuestRepository extends QuestRepository {
  _FakeQuestRepository() : super(Dio());

  @override
  Future<TodayQuests> fetchToday({double? latitude, double? longitude}) async => const TodayQuests(
    assignedDate: '2026-07-27',
    quests: [
      DailyQuest(
        dailyQuestId: 1,
        status: DailyQuestStatus.assigned,
        quest: Quest(
          id: 1,
          title: '물 여덟 잔 마시기',
          cadence: QuestCadence.daily,
          completionType: QuestCompletionType.selfReport,
          expReward: 10,
        ),
      ),
      DailyQuest(
        dailyQuestId: 2,
        status: DailyQuestStatus.assigned,
        quest: Quest(
          id: 21,
          title: '청계천 물길 따라 걷기',
          cadence: QuestCadence.daily,
          completionType: QuestCompletionType.location,
          expReward: 35,
          placeName: '청계광장',
          latitude: 37.5696,
          longitude: 126.9784,
          radiusM: 100,
        ),
      ),
      DailyQuest(
        dailyQuestId: 3,
        status: DailyQuestStatus.assigned,
        quest: Quest(
          id: 25,
          title: '새로운 카페 방문하기',
          cadence: QuestCadence.weekly,
          completionType: QuestCompletionType.location,
          expReward: 40,
          placeName: '성수동 카페거리',
          latitude: 37.5445,
          longitude: 127.0557,
          radiusM: 100,
        ),
      ),
    ],
  );
}
