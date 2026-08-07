import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/data/quest_repository.dart';
import 'package:life_quest/features/quest/presentation/quest_list_screen.dart';
import 'package:life_quest/features/recommendation/application/quest_recommendation_provider.dart';
import 'package:life_quest/features/recommendation/data/quest_recommendation_dto.dart';
import 'package:life_quest/features/recommendation/data/quest_recommendation_repository.dart';
import 'package:life_quest/features/recommendation/presentation/place_recommendation_form_screen.dart';
import 'package:life_quest/features/recommendation/presentation/recommendation_result_screen.dart';
import 'package:life_quest/features/recommendation/presentation/recommendation_type_screen.dart';
import 'package:life_quest/features/recommendation/presentation/travel_recommendation_form_screen.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
import 'package:life_quest/features/user/data/user_dto.dart';

/// 주간 AI 슬롯의 앱 쪽 흐름.
///
/// 서버 계약(슬롯 2+1, 주 1회, 후보 저장)은 백엔드 테스트가 고정한다. 여기서는
/// **앱이 그 계약을 어떻게 쓰는지**만 본다 — 어느 경로를 부르는지, 언제 버튼을
/// 띄우는지, 성공 후 어디로 가는지.
void main() {
  group('주간 모드 경로 분기', () {
    testWidgets('주간 모드는 weekly 경로로 추천을 요청한다', (tester) async {
      final repository = _FakeRecommendationRepository();
      await _pumpForm(tester, repository, '/quest-recommendations/place', weekly: true);

      await tester.enterText(
        find.widgetWithText(TextField, '지역 (예: 서울 성수동)'),
        '서울 성수동',
      );
      await _submit(tester);

      // 일반 경로를 부르면 후보가 저장되지 않아 candidateId가 없고, 결과 화면에
      // "받기" 버튼이 뜨지 않는다 — 사용자는 추천만 보고 막다른 길에 선다
      expect(repository.weeklyPlaceCalls, 1);
      expect(repository.placeCalls, 0);
    });

    testWidgets('일반 모드는 기존 경로를 그대로 쓴다', (tester) async {
      final repository = _FakeRecommendationRepository();
      await _pumpForm(tester, repository, '/quest-recommendations/place');

      await tester.enterText(
        find.widgetWithText(TextField, '지역 (예: 서울 성수동)'),
        '서울 성수동',
      );
      await _submit(tester);

      expect(repository.placeCalls, 1);
      expect(repository.weeklyPlaceCalls, 0);
    });

    testWidgets('여행도 주간 모드에서 weekly 경로로 간다', (tester) async {
      final repository = _FakeRecommendationRepository();
      await _pumpForm(tester, repository, '/quest-recommendations/travel', weekly: true);

      await tester.enterText(find.widgetWithText(TextField, '여행지 (예: 부산)'), '부산');
      await _submit(tester);

      expect(repository.weeklyTravelCalls, 1);
      expect(repository.travelCalls, 0);
    });

    testWidgets('종류 선택 화면이 주간 모드를 다음 화면으로 넘긴다', (tester) async {
      final router = GoRouter(
        initialLocation: '/quest-recommendations?weekly=true',
        routes: [
          GoRoute(
            path: '/quest-recommendations',
            builder: (_, state) => RecommendationTypeScreen(
              weekly: state.uri.queryParameters['weekly'] == 'true',
            ),
          ),
          GoRoute(
            path: '/quest-recommendations/place',
            builder: (_, state) => PlaceRecommendationFormScreen(
              weekly: state.uri.queryParameters['weekly'] == 'true',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      expect(find.text('주간 퀘스트 받기'), findsOneWidget);
      await tester.tap(find.text('장소 추천'));
      await tester.pumpAndSettle();

      final form = tester.widget<PlaceRecommendationFormScreen>(
        find.byType(PlaceRecommendationFormScreen),
      );
      expect(form.weekly, isTrue);
    });
  });

  group('결과 화면의 받기 버튼', () {
    testWidgets('candidateId가 있는 후보에만 받기 버튼이 뜬다', (tester) async {
      await _pumpResult(tester, _QuestFake(), claimable: true);

      // 세 번째 카드는 화면 밖이라 아직 만들어지지 않는다(ListView 지연 생성).
      // 스크롤해 마지막 카드까지 버튼이 붙는지 확인한다.
      expect(find.text('주간 퀘스트로 받기'), findsAtLeastNWidgets(2));
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('3. 추천 3'), findsOneWidget);
      expect(find.text('주간 퀘스트로 받기'), findsAtLeastNWidgets(1));
    });

    testWidgets('일반 추천 결과에는 받기 버튼이 없다', (tester) async {
      // 서버가 저장하지 않은 후보는 고를 수 없다. 버튼을 띄우면 눌러도 400이 난다
      await _pumpResult(tester, _QuestFake(), claimable: false);
      expect(find.text('주간 퀘스트로 받기'), findsNothing);
    });

    testWidgets('후보를 고르면 그 id로 선택 요청을 보내고 주간 탭으로 간다', (tester) async {
      final quests = _QuestFake();
      await _pumpResult(tester, quests, claimable: true);

      await _tapVisible(tester, find.text('주간 퀘스트로 받기').first);
      await tester.pumpAndSettle();

      expect(quests.claimedCandidateIds, [901]);
      // 목록 기본 탭이 일간이라 그냥 돌아가면 방금 받은 퀘스트가 안 보인다
      expect(quests.lastLocation, '/quests?tab=weekly');
    });

    testWidgets('이미 받은 주면 서버 메시지를 보여주고 이동하지 않는다', (tester) async {
      final quests = _QuestFake(
        failure: const ApiException(
          code: 'WEEKLY_AI_QUEST_ALREADY_CLAIMED',
          message: '이번 주 AI 퀘스트는 이미 받았습니다.',
          statusCode: 409,
        ),
      );
      await _pumpResult(tester, quests, claimable: true);

      await _tapVisible(tester, find.text('주간 퀘스트로 받기').first);
      await tester.pumpAndSettle();

      expect(find.text('이번 주 AI 퀘스트는 이미 받았습니다.'), findsOneWidget);
      expect(quests.lastLocation, isNull);
    });
  });

  group('목록의 주간 슬롯 안내', () {
    testWidgets('주간 탭에 AI 퀘스트가 없으면 받기 카드가 보인다', (tester) async {
      await _pumpList(tester, weeklyAiAssigned: false);

      expect(find.text('나만의 주간 퀘스트'), findsOneWidget);
    });

    testWidgets('이미 받았으면 받기 카드를 감춘다', (tester) async {
      await _pumpList(tester, weeklyAiAssigned: true);

      expect(find.text('나만의 주간 퀘스트'), findsNothing);
      expect(find.text('AI로 고른 주간 퀘스트'), findsOneWidget);
    });

    testWidgets('주간이 이미 3개면 자리가 없으므로 카드를 감춘다', (tester) async {
      // 슬롯 규칙이 바뀌기 전에 만들어진 주의 배정이 이런 모양이다. 받아도 서버가
      // 거절할 자리를 권하면 안 된다 — 다음 주기부터 자동이 2개라 자연히 열린다.
      await _pumpList(tester, weeklyAiAssigned: false, legacyWeeklyCount: 3);

      expect(find.text('나만의 주간 퀘스트'), findsNothing);
    });

    testWidgets('일간 탭에는 주간 슬롯 카드가 없다', (tester) async {
      await _pumpList(tester, weeklyAiAssigned: false, tab: 'daily');

      expect(find.text('나만의 주간 퀘스트'), findsNothing);
    });
  });
}

// --------------------------------------------------------------------- 헬퍼

Future<void> _pumpForm(
  WidgetTester tester,
  _FakeRecommendationRepository repository,
  String initialLocation, {
  bool weekly = false,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/quest-recommendations/place',
        builder: (_, _) => PlaceRecommendationFormScreen(weekly: weekly),
      ),
      GoRoute(
        path: '/quest-recommendations/travel',
        builder: (_, _) => TravelRecommendationFormScreen(weekly: weekly),
      ),
      GoRoute(
        path: '/quest-recommendations/result',
        builder: (_, state) => RecommendationResultScreen(
          result: state.extra! as QuestRecommendationResult,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        questRecommendationRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpResult(
  WidgetTester tester,
  _QuestFake quests, {
  required bool claimable,
}) async {
  final router = GoRouter(
    initialLocation: '/result',
    routes: [
      GoRoute(
        path: '/result',
        builder: (_, _) =>
            RecommendationResultScreen(result: _result(claimable: claimable)),
      ),
      GoRoute(
        path: '/quests',
        builder: (_, state) {
          quests.lastLocation = state.uri.toString();
          return const Scaffold(body: Text('퀘스트 목록'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [questRepositoryProvider.overrideWithValue(quests)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpList(
  WidgetTester tester, {
  required bool weeklyAiAssigned,
  String tab = 'weekly',
  int legacyWeeklyCount = 2,
}) async {
  final router = GoRouter(
    initialLocation: '/quests',
    routes: [
      GoRoute(
        path: '/quests',
        builder: (_, _) => QuestListScreen(initialTab: tab),
      ),
      GoRoute(
        path: '/quest-recommendations',
        builder: (_, _) => const Scaffold(body: Text('추천 화면')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        questRepositoryProvider.overrideWithValue(
          _QuestFake(
            weeklyAiAssigned: weeklyAiAssigned,
            legacyWeeklyCount: legacyWeeklyCount,
          ),
        ),
        // 주간이 잠겨 있으면 목록이 잠금 안내로 덮여 슬롯 카드가 가려진다
        levelStatusProvider.overrideWith(
          (ref) async => LevelStatus(
            level: 5,
            totalExp: 0,
            currentLevelExp: 0,
            nextLevelRequiredExp: 100,
            unlocks: QuestUnlocks(
              weekly: QuestUnlock(true, 3),
              coop: QuestUnlock(true, 5),
            ),
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

/// 제출 버튼은 긴 폼의 맨 아래에 있다. ListView는 보이는 범위만 만들므로
/// 기본 800x600 화면에서는 버튼이 아직 위젯 트리에 없다 — 나타날 때까지 내린다.
Future<void> _submit(WidgetTester tester) async {
  final button = find.text('3개 추천받기');
  for (var attempt = 0; attempt < 12 && button.evaluate().isEmpty; attempt++) {
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
  }
  await _tapVisible(tester, button);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

class _QuestFake extends QuestRepository {
  _QuestFake({
    this.weeklyAiAssigned = false,
    this.failure,
    this.legacyWeeklyCount = 2,
  }) : super(Dio());

  final bool weeklyAiAssigned;

  /// 자동 배정된 주간 퀘스트 수. 새 규칙은 2개지만, 규칙이 바뀌기 전에 만들어진
  /// 주에는 3개가 그대로 남아 있다.
  final int legacyWeeklyCount;
  final ApiException? failure;
  final List<int> claimedCandidateIds = [];
  String? lastLocation;

  @override
  Future<TodayQuests> fetchToday() async => TodayQuests(
    assignedDate: '2026-08-03',
    quests: [
      _daily(1, '일간 퀘스트', QuestCadence.daily, null),
      for (var i = 0; i < legacyWeeklyCount; i++)
        _daily(10 + i, '자동 주간 $i', QuestCadence.weekly, 'SYSTEM'),
      if (weeklyAiAssigned)
        _daily(4, 'AI로 고른 주간 퀘스트', QuestCadence.weekly, 'AI'),
    ],
  );

  @override
  Future<DailyQuest> claimWeeklyAiQuest(int candidateId) async {
    if (failure != null) throw failure!;
    claimedCandidateIds.add(candidateId);
    return _daily(4, 'AI로 고른 주간 퀘스트', QuestCadence.weekly, 'AI');
  }

  DailyQuest _daily(int id, String title, QuestCadence cadence, String? by) =>
      DailyQuest(
        dailyQuestId: id,
        status: DailyQuestStatus.assigned,
        quest: Quest(
          id: id,
          title: title,
          completionType: QuestCompletionType.selfReport,
          expReward: 40,
          cadence: cadence,
          createdBy: by,
        ),
      );
}

class _FakeRecommendationRepository extends QuestRecommendationRepository {
  _FakeRecommendationRepository() : super(Dio());

  int placeCalls = 0;
  int travelCalls = 0;
  int weeklyPlaceCalls = 0;
  int weeklyTravelCalls = 0;

  @override
  Future<QuestRecommendationResult> place(Map<String, dynamic> data) async {
    placeCalls++;
    return _result(claimable: false);
  }

  @override
  Future<QuestRecommendationResult> travel(Map<String, dynamic> data) async {
    travelCalls++;
    return _result(claimable: false, type: RecommendationType.travel);
  }

  @override
  Future<QuestRecommendationResult> weeklyPlace(
    Map<String, dynamic> data,
  ) async {
    weeklyPlaceCalls++;
    return _result(claimable: true);
  }

  @override
  Future<QuestRecommendationResult> weeklyTravel(
    Map<String, dynamic> data,
  ) async {
    weeklyTravelCalls++;
    return _result(claimable: true, type: RecommendationType.travel);
  }
}

QuestRecommendationResult _result({
  required bool claimable,
  RecommendationType type = RecommendationType.place,
}) => QuestRecommendationResult(
  provider: 'OPENAI',
  model: 'gpt-5.6-luna',
  remainingRequestsToday: 9,
  candidates: [
    for (var index = 1; index <= 3; index++)
      QuestRecommendationCandidate(
        index: index,
        // 900 + index — 저장된 후보만 id를 가진다
        candidateId: claimable ? 900 + index : null,
        type: type,
        title: '추천 $index',
        description: '추천 설명 $index',
        category: 'CULTURE',
        durationValue: type == RecommendationType.place ? 120 : 2,
        durationUnit: type == RecommendationType.place ? 'MINUTES' : 'DAYS',
        estimatedCostPerPerson: 10000,
        suggestedPlaceName: '추천 장소 $index',
        completionGuide: '경험을 완료하고 기록하세요',
      ),
  ],
);
