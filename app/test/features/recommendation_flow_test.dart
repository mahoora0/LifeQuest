import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/recommendation/application/quest_recommendation_provider.dart';
import 'package:life_quest/features/recommendation/data/quest_recommendation_dto.dart';
import 'package:life_quest/features/recommendation/data/quest_recommendation_repository.dart';
import 'package:life_quest/features/recommendation/presentation/place_recommendation_form_screen.dart';
import 'package:life_quest/features/recommendation/presentation/recommendation_result_screen.dart';
import 'package:life_quest/features/recommendation/presentation/recommendation_type_screen.dart';
import 'package:life_quest/features/recommendation/presentation/travel_recommendation_form_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('추천 종류에서 장소와 여행 입력 화면으로 이동한다', (tester) async {
    final router = GoRouter(
      initialLocation: '/quest-recommendations',
      routes: [
        GoRoute(
          path: '/quest-recommendations',
          builder: (_, _) => const RecommendationTypeScreen(),
        ),
        GoRoute(
          path: '/quest-recommendations/place',
          builder: (_, _) => const PlaceRecommendationFormScreen(),
        ),
        GoRoute(
          path: '/quest-recommendations/travel',
          builder: (_, _) => const TravelRecommendationFormScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.text('장소 추천'), findsOneWidget);
    expect(find.text('여행 추천'), findsOneWidget);
    await tester.tap(find.text('장소 추천'));
    await tester.pumpAndSettle();
    expect(find.text('장소 추천 조건'), findsOneWidget);
  });

  testWidgets('장소 조건을 보내고 세 후보 결과를 표시한다', (tester) async {
    final repository = _FakeRecommendationRepository();
    await _pumpForm(tester, repository, '/quest-recommendations/place');

    await tester.enterText(
      find.widgetWithText(TextField, '지역 (예: 서울 성수동)'),
      '서울 성수동',
    );
    await _tapVisible(tester, find.text('산책'));
    await _tapVisible(tester, find.text('문화·전시'));
    await _tapVisible(tester, find.text('3개 추천받기'));
    await tester.pumpAndSettle();

    expect(repository.placeCalls, 1);
    expect(repository.lastPlace?['area'], '서울 성수동');
    expect(repository.lastPlace?['availableMinutes'], 180);
    expect(repository.lastPlace?['budgetPerPerson'], 30000);
    expect(repository.lastPlace?['companionCount'], 1);
    expect(repository.lastPlace?['environment'], 'ANY');
    expect(repository.lastPlace?['interests'], ['산책', '문화·전시']);
    expect(find.text('추천 결과'), findsOneWidget);
    expect(find.text('1. 추천 1'), findsOneWidget);
    expect(find.text('2. 추천 2'), findsOneWidget);
    expect(find.text('3. 추천 3'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('오늘 남은 추천 9회 · gpt-5.6-luna'), findsOneWidget);
  });

  testWidgets('필수 장소가 없으면 API를 호출하지 않고 입력 오류를 알린다', (tester) async {
    final repository = _FakeRecommendationRepository();
    await _pumpForm(tester, repository, '/quest-recommendations/place');

    await _tapVisible(tester, find.text('3개 추천받기'));
    await tester.pump();

    expect(repository.placeCalls, 0);
    expect(find.text('지역·시간·예산·인원·관심사 입력 범위를 확인해 주세요'), findsOneWidget);
  });

  testWidgets('여행 조건은 기간 단위와 함께 여행 추천 API로 전달한다', (tester) async {
    final repository = _FakeRecommendationRepository();
    await _pumpForm(tester, repository, '/quest-recommendations/travel');

    await tester.enterText(find.widgetWithText(TextField, '여행지 (예: 부산)'), '부산');
    await _tapVisible(tester, find.text('3개 추천받기'));
    await tester.pumpAndSettle();

    expect(repository.travelCalls, 1);
    expect(repository.lastTravel?['destination'], '부산');
    expect(repository.lastTravel?['days'], 2);
    expect(find.text('예상 시간 · 2 일'), findsNWidgets(3));
  });

  testWidgets('추천 제공자 시간 초과를 결과 화면 전환 없이 안내한다', (tester) async {
    final repository = _FakeRecommendationRepository(fail: true);
    await _pumpForm(tester, repository, '/quest-recommendations/place');

    await tester.enterText(
      find.widgetWithText(TextField, '지역 (예: 서울 성수동)'),
      '서울 성수동',
    );
    await _tapVisible(tester, find.text('3개 추천받기'));
    await tester.pumpAndSettle();

    expect(repository.placeCalls, 1);
    expect(find.text('추천 생성 시간이 초과되었습니다.'), findsOneWidget);
    expect(find.text('추천 결과'), findsNothing);
  });

  testWidgets('장소 프리셋과 인원 스테퍼를 API 값으로 변환한다', (tester) async {
    final repository = _FakeRecommendationRepository();
    await _pumpForm(tester, repository, '/quest-recommendations/place');

    await tester.enterText(
      find.widgetWithText(TextField, '지역 (예: 서울 성수동)'),
      '강남역',
    );
    await _tapVisible(tester, find.text('1시간'));
    await _tapVisible(tester, find.text('1만원 이하'));
    await _tapVisible(tester, find.bySemanticsLabel('인원 1명 늘리기'));
    await _tapVisible(tester, find.text('실내'));
    await _tapVisible(tester, find.text('카페'));
    await _tapVisible(tester, find.text('독서'));
    await _tapVisible(tester, find.text('3개 추천받기'));
    await tester.pumpAndSettle();

    expect(repository.lastPlace?['availableMinutes'], 60);
    expect(repository.lastPlace?['budgetPerPerson'], 10000);
    expect(repository.lastPlace?['companionCount'], 2);
    expect(repository.lastPlace?['environment'], 'INDOOR');
    expect(repository.lastPlace?['interests'], ['카페', '독서']);
  });

  testWidgets('장소 시간과 예산은 프리셋 밖의 값을 직접 입력할 수 있다', (tester) async {
    final repository = _FakeRecommendationRepository();
    await _pumpForm(tester, repository, '/quest-recommendations/place');

    await tester.enterText(
      find.widgetWithText(TextField, '지역 (예: 서울 성수동)'),
      '서울 성수동',
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('recommendation-choice-가능 시간-직접 입력')),
    );
    await tester.enterText(
      find.widgetWithText(TextField, '가능 시간 직접 입력'),
      '240',
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('recommendation-choice-1인 예산-직접 입력')),
    );
    await tester.enterText(
      find.widgetWithText(TextField, '1인 예산 직접 입력'),
      '75000',
    );
    await _tapVisible(tester, find.text('3개 추천받기'));
    await tester.pumpAndSettle();

    expect(repository.lastPlace?['availableMinutes'], 240);
    expect(repository.lastPlace?['budgetPerPerson'], 75000);
  });

  testWidgets('관심사는 선택과 직접 추가를 합쳐 전달하고 5개 선택을 제한한다', (tester) async {
    final repository = _FakeRecommendationRepository();
    await _pumpForm(tester, repository, '/quest-recommendations/place');

    await tester.enterText(
      find.widgetWithText(TextField, '지역 (예: 서울 성수동)'),
      '강남역',
    );

    for (final interest in ['맛집', '카페', '산책', '자연', '문화·전시']) {
      await _tapVisible(tester, find.text(interest));
    }
    await _tapVisible(tester, find.text('운동'));
    expect(find.text('관심사는 최대 5개까지 선택할 수 있어요'), findsOneWidget);
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('맛집'));
    await _tapVisible(tester, find.text('직접 추가'));
    await tester.enterText(find.widgetWithText(TextField, '직접 관심사'), '북카페');
    await _tapVisible(tester, find.text('3개 추천받기'));
    await tester.pumpAndSettle();

    expect(repository.lastPlace?['interests'], [
      '카페',
      '산책',
      '자연',
      '문화·전시',
      '북카페',
    ]);
  });

  testWidgets('여행 프리셋을 기간과 예산 값으로 전달한다', (tester) async {
    final repository = _FakeRecommendationRepository();
    await _pumpForm(tester, repository, '/quest-recommendations/travel');

    await tester.enterText(
      find.widgetWithText(TextField, '여행지 (예: 부산)'),
      '제주도',
    );
    await _tapVisible(tester, find.text('2박 3일'));
    await _tapVisible(tester, find.text('50만원 이하'));
    await _tapVisible(tester, find.text('바다'));
    await _tapVisible(tester, find.text('휴식'));
    await _tapVisible(tester, find.text('3개 추천받기'));
    await tester.pumpAndSettle();

    expect(repository.lastTravel?['days'], 3);
    expect(repository.lastTravel?['budgetPerPerson'], 500000);
    expect(repository.lastTravel?['interests'], ['바다', '휴식']);
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  final list = find.byType(ListView);
  var attempts = 0;
  while (finder.evaluate().isEmpty && attempts < 20) {
    await tester.drag(list, const Offset(0, -240));
    await tester.pumpAndSettle();
    attempts++;
  }
  expect(finder, findsWidgets);
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pump();
}

Future<void> _pumpForm(
  WidgetTester tester,
  _FakeRecommendationRepository repository,
  String initialLocation,
) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/quest-recommendations/place',
        builder: (_, _) => const PlaceRecommendationFormScreen(),
      ),
      GoRoute(
        path: '/quest-recommendations/travel',
        builder: (_, _) => const TravelRecommendationFormScreen(),
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

class _FakeRecommendationRepository extends QuestRecommendationRepository {
  _FakeRecommendationRepository({this.fail = false}) : super(Dio());
  final bool fail;
  int placeCalls = 0;
  int travelCalls = 0;
  Map<String, dynamic>? lastPlace;
  Map<String, dynamic>? lastTravel;

  @override
  Future<QuestRecommendationResult> place(Map<String, dynamic> data) async {
    placeCalls++;
    lastPlace = data;
    if (fail) {
      throw const ApiException(
        code: 'LLM_PROVIDER_TIMEOUT',
        message: '추천 생성 시간이 초과되었습니다.',
        statusCode: 504,
      );
    }
    return _result(RecommendationType.place);
  }

  @override
  Future<QuestRecommendationResult> travel(Map<String, dynamic> data) async {
    travelCalls++;
    lastTravel = data;
    return _result(RecommendationType.travel);
  }
}

QuestRecommendationResult _result(RecommendationType type) =>
    QuestRecommendationResult(
      provider: 'OPENAI',
      model: 'gpt-5.6-luna',
      remainingRequestsToday: 9,
      candidates: [
        for (var index = 1; index <= 3; index++)
          QuestRecommendationCandidate(
            index: index,
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
