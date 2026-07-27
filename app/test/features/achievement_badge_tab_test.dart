import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:life_quest/features/achievement/application/achievement_providers.dart';
import 'package:life_quest/features/achievement/data/achievement_dto.dart';
import 'package:life_quest/features/achievement/data/achievement_repository.dart';
import 'package:life_quest/features/achievement/presentation/achievement_screen.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
import 'package:life_quest/features/user/data/user_dto.dart';
import 'package:life_quest/features/user/data/user_repository.dart';

/// 마이페이지의 "내 배지" 카드가 "나의 기록"으로 대체되면서 업적 화면의 배지 탭이
/// 대표 배지를 지정할 수 있는 유일한 경로가 됐다.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<_FakeUserRepository> pumpAchievements(
    WidgetTester tester, {
    int initialTab = 0,
  }) async {
    final userRepository = _FakeUserRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(userRepository),
          achievementRepositoryProvider.overrideWithValue(
            _FakeAchievementRepository(),
          ),
        ],
        child: MaterialApp(home: AchievementScreen(initialTab: initialTab)),
      ),
    );
    await tester.pumpAndSettle();
    return userRepository;
  }

  testWidgets('업적·칭호·배지 세 탭을 제공한다', (tester) async {
    await pumpAchievements(tester);

    expect(find.text('업적'), findsOneWidget);
    expect(find.text('칭호'), findsOneWidget);
    expect(find.text('배지'), findsOneWidget);
  });

  testWidgets('배지 탭은 보유 배지와 현재 대표를 보여준다', (tester) async {
    await pumpAchievements(tester, initialTab: 2);

    expect(find.text('탭하면 대표 배지로 지정돼요 — 다시 누르면 해제됩니다'), findsOneWidget);
    expect(find.text('새싹 배지'), findsOneWidget);
    expect(find.text('나침반 배지'), findsOneWidget);
    expect(find.text('레벨업 보상'), findsNWidgets(2));
    expect(find.text('업적 보상'), findsOneWidget);

    // representativeBadgeId = 1 → 새싹 배지 한 건에만 체크가 붙는다.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('배지를 탭하면 대표로 지정되고 서버에 전달된다', (tester) async {
    final userRepository = await pumpAchievements(tester, initialTab: 2);

    await tester.tap(find.text('황금 모험가 배지'));
    await tester.pumpAndSettle();

    expect(userRepository.requestedBadgeIds, [3]);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('같은 배지를 다시 탭하면 대표가 해제된다', (tester) async {
    final userRepository = await pumpAchievements(tester, initialTab: 2);

    await tester.tap(find.text('새싹 배지'));
    await tester.pumpAndSettle();

    // 해제는 null을 보내야 서버가 대표 없음으로 되돌린다.
    expect(userRepository.requestedBadgeIds, [null]);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });
}

class _FakeUserRepository extends UserRepository {
  _FakeUserRepository() : super(Dio());

  final List<int?> requestedBadgeIds = [];

  @override
  Future<BadgeCollection> fetchBadges() async => const BadgeCollection(
    badges: [
      ProfileItem(id: 1, name: '새싹 배지', sourceType: 'LEVEL'),
      ProfileItem(id: 2, name: '나침반 배지', sourceType: 'LEVEL'),
      ProfileItem(id: 3, name: '황금 모험가 배지', sourceType: 'ACHIEVEMENT'),
    ],
    representativeBadgeId: 1,
  );

  @override
  Future<void> updateRepresentativeBadge(int? badgeId) async {
    requestedBadgeIds.add(badgeId);
  }

  @override
  Future<TitleCollection> fetchTitles() async =>
      const TitleCollection(titles: [], representativeTitleId: null);
}

class _FakeAchievementRepository extends AchievementRepository {
  _FakeAchievementRepository() : super(Dio());

  @override
  Future<AchievementOverview> fetchOverview() async =>
      const AchievementOverview(
        achievements: [
          Achievement(id: 1, name: '첫걸음', achieved: true, secret: false),
        ],
      );
}
