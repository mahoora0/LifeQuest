import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/achievement/application/achievement_providers.dart';
import 'package:life_quest/features/achievement/data/achievement_dto.dart';
import 'package:life_quest/features/achievement/data/achievement_repository.dart';
import 'package:life_quest/features/achievement/presentation/achievement_screen.dart';
import 'package:life_quest/features/lifedex/application/lifedex_providers.dart';
import 'package:life_quest/features/lifedex/data/lifedex_dto.dart';
import 'package:life_quest/features/lifedex/data/lifedex_repository.dart';
import 'package:life_quest/features/lifedex/presentation/lifedex_screen.dart';

/// 백엔드에 컨트롤러가 없는 도감·업적의 두 갈래를 고정한다.
///
/// 1. 표본이 꺼진 기본 상태(= 빌드 산출물)에서는 **가짜가 아니라 준비 중 안내**가 뜬다.
/// 2. 데이터가 주어지면 화면은 준비 중이 아니라 내용을 그린다.
///
/// 표본 상수 자체는 검토용이라 값을 단언하지 않는다 — 값을 박아 두면 시안이 바뀔 때마다
/// 테스트가 따라다니면서도 사용자가 보는 것은 아무것도 보장하지 못한다.
void main() {
  /// 컨트롤러가 없는 서버를 흉내 낸다.
  ///
  /// 백엔드가 미매핑 경로에 붙이는 응답 모양 그대로다 — 404 + envelope의
  /// `ENDPOINT_NOT_FOUND`. 본문을 비운 404로 두면 실제 서버와 다른 것을 검사하게 된다.
  Dio unreachableDio() {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: 404,
              data: const {
                'success': false,
                'data': null,
                'error': {
                  'code': 'ENDPOINT_NOT_FOUND',
                  'message': '아직 제공되지 않는 기능입니다.',
                },
              },
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
      ),
    );
    return dio;
  }

  Future<void> pumpLifedex(WidgetTester tester, LifedexRepository repo) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [lifedexRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: LifedexScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpAchievement(
    WidgetTester tester,
    AchievementRepository repo,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [achievementRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: AchievementScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('표본이 꺼진 기본 상태', () {
    testWidgets('도감은 가짜 수집 현황 대신 준비 중을 보여준다', (tester) async {
      await pumpLifedex(tester, LifedexRepository(unreachableDio()));

      expect(find.text('일일 퀘스트 도감은 아직 준비 중이에요'), findsOneWidget);
      expect(find.textContaining('수집률'), findsNothing);
      // 탭 밖 push 화면이라 돌아갈 길은 남아야 한다.
      expect(find.bySemanticsLabel('뒤로 가기'), findsOneWidget);
    });

    testWidgets('업적도 마찬가지로 준비 중을 보여준다', (tester) async {
      await pumpAchievement(tester, AchievementRepository(unreachableDio()));

      expect(find.text('업적 목록은 아직 준비 중이에요'), findsOneWidget);
    });
  });

  group('데이터가 있을 때', () {
    testWidgets('도감은 카테고리와 수집 개수를 그린다', (tester) async {
      await pumpLifedex(tester, _FakeLifedexRepository());

      expect(find.text('일일 퀘스트 도감은 아직 준비 중이에요'), findsNothing);
      expect(find.text('일일 퀘스트 전용'), findsOneWidget);
      expect(
        find.text('도감 표시가 있는 일일 퀘스트를 완료하면 새로운 기록이 등록돼요.'),
        findsOneWidget,
      );
      // 카테고리는 필터 칩과 격자 타일 양쪽에 나온다.
      expect(find.text('카페'), findsWidgets);
      expect(find.text('공원 · 산책로'), findsWidgets);
      // 12+8 = 20개를 수집했다.
      expect(find.text('20개'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('업적은 달성과 진행 중을 함께 그린다', (tester) async {
      await pumpAchievement(tester, _FakeAchievementRepository());

      expect(find.text('업적 목록은 아직 준비 중이에요'), findsNothing);
      expect(find.text('첫 걸음'), findsOneWidget);
      expect(find.text('꾸준한 모험가'), findsOneWidget);
    });

    testWidgets('미달성 비밀 업적의 빈 이름을 대체 문구로 그린다', (tester) async {
      await pumpAchievement(tester, _FakeAchievementRepository());

      // 마스킹은 서버가 이름을 비워 보내는 것으로 표현된다. 화면이 그걸 대체하지
      // 않으면 빈 줄이 뜨고, `characters.first` 계열 코드는 아예 던진다.
      await tester.tap(find.text('비밀'));
      await tester.pumpAndSettle();

      expect(find.text('비밀 업적'), findsOneWidget);
      expect(find.text('야행성 탐험가'), findsOneWidget);
    });
  });
}

class _FakeLifedexRepository extends LifedexRepository {
  _FakeLifedexRepository() : super(Dio());

  @override
  Future<LifedexOverview> fetchOverview() async => const LifedexOverview(
    categories: [
      LifedexCategory(id: 1, name: '카페', totalCount: 24, ownedCount: 12),
      LifedexCategory(id: 2, name: '공원 · 산책로', totalCount: 16, ownedCount: 8),
    ],
  );

  @override
  Future<List<LifedexItem>> fetchItems(int categoryId) async => const [
    LifedexItem(id: 101, name: '골목 끝 로스터리', categoryId: 1, owned: true),
  ];
}

class _FakeAchievementRepository extends AchievementRepository {
  _FakeAchievementRepository() : super(Dio());

  @override
  Future<AchievementOverview> fetchOverview() async =>
      const AchievementOverview(
        achievements: [
          Achievement(
            id: 1,
            name: '첫 걸음',
            achieved: true,
            secret: false,
            condition: '퀘스트를 처음 완료해요',
          ),
          Achievement(
            id: 3,
            name: '꾸준한 모험가',
            achieved: false,
            secret: false,
            currentValue: 32,
            requiredValue: 50,
          ),
          // 마스킹된 비밀 업적 — 이름이 비어 있다.
          Achievement(id: 5, name: '', achieved: false, secret: true),
          Achievement(
            id: 6,
            name: '야행성 탐험가',
            achieved: true,
            secret: true,
            condition: '자정 넘어 퀘스트를 5번 완료했어요',
          ),
        ],
      );
}
