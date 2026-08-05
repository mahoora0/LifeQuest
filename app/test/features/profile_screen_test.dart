import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/core/network/provider_retry.dart';
import 'package:life_quest/features/achievement/application/achievement_providers.dart';
import 'package:life_quest/features/achievement/data/achievement_dto.dart';
import 'package:life_quest/features/achievement/data/achievement_repository.dart';
import 'package:life_quest/features/lifedex/application/lifedex_providers.dart';
import 'package:life_quest/features/lifedex/data/lifedex_dto.dart';
import 'package:life_quest/features/lifedex/data/lifedex_repository.dart';
import 'package:life_quest/features/profile/presentation/profile_screen.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/quest/data/quest_repository.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
import 'package:life_quest/features/user/data/user_dto.dart';
import 'package:life_quest/features/user/data/user_repository.dart';

/// 마이페이지는 대표 배지 지정 결과가 돌아와 보이는 화면이고, 서버가 아직 없는
/// 구간(도감·업적)을 오류가 아니라 준비 중으로 알려야 하는 화면이기도 하다.
void main() {
  Future<void> pumpProfile(WidgetTester tester) async {
    // 카드가 많아 기본 600 높이에서는 아래쪽 카드가 build되지 않는다.
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        // 앱과 같은 재시도 정책을 써야 404가 즉시 실패로 확정된다.
        retry: lqProviderRetry,
        overrides: [
          userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
          questRepositoryProvider.overrideWithValue(_FakeQuestRepository()),
          lifedexRepositoryProvider.overrideWithValue(_FakeLifedexRepository()),
          achievementRepositoryProvider.overrideWithValue(
            _FakeAchievementRepository(),
          ),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    // "나의 기록" 카드는 프로필 조회가 끝난 뒤에야 처음 build되고, 그 시점에
    // 도감·업적 provider가 초기화된다. 그 두 번째 조회 결과까지 기다린다.
    await tester.pumpAndSettle();
  }

  testWidgets('마이페이지에 배지 영역을 표시하지 않는다', (tester) async {
    await pumpProfile(tester);

    expect(find.text('내 배지'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('대표 배지')), findsNothing);
  });

  testWidgets('최근 획득 영역을 표시하지 않는다', (tester) async {
    await pumpProfile(tester);

    expect(find.text('최근 획득'), findsNothing);
    expect(find.text('획득 보상'), findsNothing);
    expect(find.text('내 캐릭터'), findsNothing);
  });

  testWidgets('서버가 없는 구간은 오류가 아니라 준비 중으로 알린다', (tester) async {
    await pumpProfile(tester);

    // 도감·업적 두 줄 모두 404다.
    expect(find.text('준비 중이에요'), findsNWidgets(2));
    expect(find.text('현황을 불러오지 못했어요'), findsNothing);
  });

  testWidgets('구현된 조회는 그대로 수치를 보여준다', (tester) async {
    await pumpProfile(tester);

    // 퀘스트 완료 카운트와 총 EXP는 서버가 응답하는 구간이다.
    expect(find.text('12'), findsOneWidget);
    expect(find.text('350'), findsOneWidget);
  });

  testWidgets('상단에 캐릭터와 사용자 정보를 좌우로 표시한다', (tester) async {
    await pumpProfile(tester);

    expect(find.text('캐릭터 꾸미기'), findsOneWidget);
    expect(find.bySemanticsLabel('프로필 사진 변경'), findsOneWidget);
    expect(find.text('모험가'), findsOneWidget);
    expect(find.text('길잡이'), findsOneWidget);
    expect(find.text('Lv. 3'), findsOneWidget);
    expect(find.text('변경'), findsOneWidget);
  });
}

/// 매핑된 컨트롤러가 없는 경로에서 오는 응답.
///
/// 백엔드가 `NoResourceFoundException`을 잡아 404 + `ENDPOINT_NOT_FOUND`로 내보낸다.
ApiException _notFound(String path) => ApiException.from(
  DioException(
    requestOptions: RequestOptions(path: path),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: 404,
      data: const {
        'success': false,
        'data': null,
        'error': {'code': 'ENDPOINT_NOT_FOUND', 'message': '아직 제공되지 않는 기능입니다.'},
      },
    ),
    type: DioExceptionType.badResponse,
  ),
);

class _FakeUserRepository extends UserRepository {
  _FakeUserRepository() : super(Dio());

  @override
  Future<UserProfile> fetchMe() async => const UserProfile(
    id: 1,
    nickname: '모험가',
    representativeTitle: '길잡이',
    representativeTitleId: 9,
    representativeBadge: '나침반 배지',
    representativeBadgeId: 5,
  );

  @override
  Future<LevelStatus> fetchLevel() async => const LevelStatus(
    level: 3,
    totalExp: 350,
    currentLevelExp: 50,
    nextLevelRequiredExp: 300,
  );

  @override
  Future<RewardHistory> fetchRewards() async => RewardHistory(
    titles: [
      UserTitle(id: 1, name: '새내기 모험가', acquiredAt: DateTime(2026, 7, 20)),
    ],
    profileItems: [
      ProfileItem(
        id: 5,
        name: '나침반 배지',
        itemType: 'BADGE',
        acquiredAt: DateTime(2026, 7, 26),
      ),
      ProfileItem(
        id: 4,
        name: '이름표',
        itemType: 'NAMEPLATE',
        acquiredAt: DateTime(2026, 7, 22),
      ),
    ],
  );

  /// 대표(id 5)를 일부러 마지막에 둬서 미리보기 정렬이 필요한 상태를 만든다.
  @override
  Future<BadgeCollection> fetchBadges() async => const BadgeCollection(
    badges: [
      ProfileItem(id: 1, name: '새싹 배지'),
      ProfileItem(id: 2, name: '별빛 배지'),
      ProfileItem(id: 3, name: '숲길 배지'),
      ProfileItem(id: 4, name: '달빛 배지'),
      ProfileItem(id: 5, name: '나침반 배지'),
    ],
    representativeBadgeId: 5,
  );

  @override
  Future<TitleCollection> fetchTitles() async =>
      const TitleCollection(titles: [], representativeTitleId: null);
}

class _FakeQuestRepository extends QuestRepository {
  _FakeQuestRepository() : super(Dio());

  @override
  Future<QuestHistoryPage> fetchHistory({int page = 0, int size = 20}) async =>
      const QuestHistoryPage(
        totalElements: 12,
        content: <Map<String, dynamic>>[],
      );
}

class _FakeLifedexRepository extends LifedexRepository {
  _FakeLifedexRepository() : super(Dio());

  @override
  Future<LifedexOverview> fetchOverview() async =>
      throw _notFound('/lifedex/categories');
}

class _FakeAchievementRepository extends AchievementRepository {
  _FakeAchievementRepository() : super(Dio());

  @override
  Future<AchievementOverview> fetchOverview() async =>
      throw _notFound('/achievements');
}
