import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
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
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

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

  testWidgets('대표 배지를 헤더와 배지 카드 양쪽에 표시한다', (tester) async {
    await pumpProfile(tester);

    // 헤더의 표식과 "내 배지" 첫 칸 — 지정 결과가 두 곳에서 함께 읽힌다.
    // 라벨은 자식 Text와 병합되므로 부분 일치로 찾는다.
    expect(find.bySemanticsLabel(RegExp('대표 배지 나침반 배지')), findsNWidgets(2));
  });

  testWidgets('대표 배지가 뒤쪽에 있어도 4칸 미리보기 안으로 끌어온다', (tester) async {
    await pumpProfile(tester);

    // 대표(id 5)는 보유 목록의 마지막이라 정렬하지 않으면 4칸에서 밀려난다.
    // 헤더 표식과 미리보기 첫 칸 두 곳에서 같은 첫 글자를 쓴다.
    expect(find.text('나'), findsNWidgets(2));
    // 대표를 앞으로 당긴 만큼 마지막 칸 하나가 미리보기 밖으로 나간다.
    expect(find.text('달'), findsNothing);
  });

  testWidgets('최근 획득은 획득 시각 최신순으로 보여준다', (tester) async {
    await pumpProfile(tester);

    expect(find.text('최근 획득'), findsOneWidget);
    // 캐릭터 카드를 대체했으므로 이전 "획득 보상" 카드는 남아 있지 않다.
    expect(find.text('획득 보상'), findsNothing);
    expect(find.text('내 캐릭터'), findsNothing);

    final names = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .where((data) => data == '나침반 배지' || data == '이름표' || data == '새내기 모험가')
        .toList();
    expect(names, ['나침반 배지', '이름표', '새내기 모험가']);
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
    // 최근 획득 목록의 칭호와 다른 이름을 써서 헤더 표시와 섞이지 않게 한다.
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
