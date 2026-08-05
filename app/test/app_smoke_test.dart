import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/app/life_quest_app.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/achievement/application/achievement_providers.dart';
import 'package:life_quest/features/achievement/data/achievement_dto.dart';
import 'package:life_quest/features/achievement/data/achievement_repository.dart';
import 'package:life_quest/features/auth/application/auth_controller.dart';
import 'package:life_quest/features/lifedex/application/lifedex_providers.dart';
import 'package:life_quest/features/lifedex/data/lifedex_dto.dart';
import 'package:life_quest/features/lifedex/data/lifedex_repository.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/data/quest_repository.dart';
import 'package:life_quest/features/profile/presentation/profile_screen.dart';
import 'package:life_quest/features/profile/presentation/profile_edit_screen.dart';
import 'package:life_quest/features/profile/presentation/character_selection_screen.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
import 'package:life_quest/features/user/data/user_dto.dart';
import 'package:life_quest/features/user/data/user_repository.dart';

void main() {
  testWidgets('시안 확정 탭 구성을 표시한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storedAuthSessionProvider.overrideWith(
            (ref) async => AuthSession.authenticated,
          ),
          questRepositoryProvider.overrideWithValue(_FakeQuestRepository()),
          userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
        ],
        child: const LifeQuestApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('홈'), findsOneWidget);
    expect(find.text('퀘스트'), findsOneWidget);
    expect(find.text('지도'), findsOneWidget);
    expect(find.text('친구'), findsOneWidget);
    expect(find.text('마이'), findsOneWidget);

    // LifeDex는 탭에서 빠지고 마이페이지 "나의 기록"에서 push로 연다.
    expect(find.text('LifeDex'), findsNothing);
  });

  testWidgets('로그아웃 상태에서는 로그인 화면을 표시한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storedAuthSessionProvider.overrideWith(
            (ref) async => AuthSession.unauthenticated,
          ),
        ],
        child: const LifeQuestApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('다시 만난 모험가님!'), findsOneWidget);
    expect(find.text('로그인'), findsOneWidget);
    expect(find.text('Google로 계속하기'), findsOneWidget);
    expect(find.text('회원가입'), findsOneWidget);
  });

  testWidgets('배정된 퀘스트가 없으면 빈 상태를 보여준다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storedAuthSessionProvider.overrideWith(
            (ref) async => AuthSession.authenticated,
          ),
          questRepositoryProvider.overrideWithValue(_FakeQuestRepository()),
          userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
        ],
        child: const LifeQuestApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('오늘의 퀘스트'), findsOneWidget);
    expect(find.text('오늘 배정된 퀘스트가 없어요'), findsOneWidget);
    expect(find.text('안녕하세요, 테스터님!\n오늘도 멋진 하루가 될 거예요!'), findsOneWidget);
    expect(find.text('Lv. 3'), findsOneWidget);
  });

  testWidgets('오늘의 퀘스트 조회가 실패해도 오류 상태가 카드 밖으로 넘치지 않는다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storedAuthSessionProvider.overrideWith(
            (ref) async => AuthSession.authenticated,
          ),
          questRepositoryProvider.overrideWithValue(_FailingQuestRepository()),
          userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
        ],
        child: const LifeQuestApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('서버 오류가 발생했습니다.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);

    // 카드가 오류 상태를 고정 높이로 가두면 RenderFlex가 paint 단계에서
    // 오버플로를 보고한다(캐릭터 108 + 여백 14 + 문구 22 + 여백 16 + 버튼 50
    // + 상하 패딩 48 = 258 > 250). 최소 높이로 두면 카드가 대신 늘어난다.
    expect(tester.takeException(), isNull);
  });

  testWidgets('로그아웃 전에 기록 보존 안내와 확인 선택지를 보여준다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questRepositoryProvider.overrideWithValue(_FakeQuestRepository()),
          userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('로그아웃'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();

    expect(find.text('로그아웃할까요?'), findsOneWidget);
    expect(
      find.text('현재 기기에서만 로그아웃돼요.\n퀘스트와 성장 기록은 그대로 보관됩니다.'),
      findsOneWidget,
    );
    expect(find.text('취소'), findsOneWidget);
    expect(find.text('로그아웃'), findsNWidgets(2));

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('로그아웃할까요?'), findsNothing);
  });

  testWidgets('마이페이지는 배지 요약 없이 나의 기록을 보여준다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questRepositoryProvider.overrideWithValue(_FakeQuestRepository()),
          userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
          lifedexRepositoryProvider.overrideWithValue(_FakeLifedexRepository()),
          achievementRepositoryProvider.overrideWithValue(
            _FakeAchievementRepository(),
          ),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('나의 기록'), findsOneWidget);
    expect(find.text('도감'), findsOneWidget);
    expect(find.text('42개 수집'), findsOneWidget);
    expect(find.text('업적 / 칭호'), findsOneWidget);
    expect(find.text('달성 1 / 3 · 칭호 2개 보유'), findsOneWidget);

    expect(find.text('내 배지'), findsNothing);

    // 칭호 변경은 업적 화면의 칭호 탭에서 한다.
    expect(find.text('칭호 선택'), findsNothing);
  });

  testWidgets('프로필 수정은 닉네임과 프로필 사진만 변경한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
        ],
        child: const MaterialApp(home: ProfileEditScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('프로필 이미지 URL'), findsNothing);
    expect(find.text('사진 선택'), findsOneWidget);
    expect(find.text('닉네임 저장'), findsOneWidget);
    expect(find.text('내 캐릭터'), findsNothing);
    expect(find.text('루키'), findsNothing);
  });

  testWidgets('캐릭터 꾸미기는 별도 화면에서 제공한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
        ],
        child: const MaterialApp(home: CharacterSelectionScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('캐릭터 꾸미기'), findsOneWidget);
    expect(find.text('루키'), findsOneWidget);
    expect(find.text('모각'), findsOneWidget);
    expect(find.text('액세서리'), findsOneWidget);
    expect(find.text('앞치마'), findsOneWidget);
    // 잠금 캐릭터가 비분리 ColorFilter 합성 레이어를 만들면 Android에서
    // 본문 전체가 회색으로 덮일 수 있다.
    expect(find.byType(ColorFiltered), findsNothing);

    final cardCenter = tester.getCenter(
      find.byKey(const ValueKey('character-card-1')),
    );
    final imageCenter = tester.getCenter(
      find.byKey(const ValueKey('character-image-1')),
    );
    expect(imageCenter.dx, closeTo(cardCenter.dx, 0.1));

    await tester.tap(find.text('앞치마'));
    await tester.pumpAndSettle();
    expect(find.text('루키 착용 미리보기'), findsOneWidget);
    expect(find.text('착용하기'), findsOneWidget);
  });
}

class _FakeQuestRepository extends QuestRepository {
  _FakeQuestRepository() : super(Dio());

  @override
  Future<TodayQuests> fetchToday() async =>
      const TodayQuests(assignedDate: '2026-07-24', quests: []);
}

/// 서버가 아직 `GET /quests/today`를 제공하지 않을 때의 홈 화면 상태를 재현한다.
class _FailingQuestRepository extends QuestRepository {
  _FailingQuestRepository() : super(Dio());

  @override
  Future<TodayQuests> fetchToday() async => throw const ApiException(
    code: 'INTERNAL_SERVER_ERROR',
    message: '서버 오류가 발생했습니다.',
    statusCode: 500,
  );
}

class _FakeUserRepository extends UserRepository {
  _FakeUserRepository() : super(Dio());

  @override
  Future<UserProfile> fetchMe() async => const UserProfile(
    id: 1,
    nickname: '테스터',
    selectedCharacter: AvatarCharacter(
      id: 1,
      code: 'ROOKIE',
      name: '루키',
      assetKey: 'rookie.png',
    ),
  );

  @override
  Future<LevelStatus> fetchLevel() async => const LevelStatus(
    level: 3,
    totalExp: 260,
    currentLevelExp: 60,
    nextLevelRequiredExp: 200,
  );

  @override
  Future<List<AvatarCharacter>> fetchCharacters() async => const [
    AvatarCharacter(id: 1, code: 'ROOKIE', name: '루키', assetKey: 'rookie.png'),
    AvatarCharacter(id: 2, code: 'MOGAK', name: '모각', assetKey: 'mogak.png'),
    AvatarCharacter(
      id: 4,
      code: 'TOTO',
      name: '토토',
      assetKey: 'toto.png',
      requiredLevel: 15,
      unlocked: false,
    ),
  ];

  @override
  Future<AccessoryCollection> fetchAccessories() async =>
      const AccessoryCollection(
        selectedAccessoryId: null,
        accessories: [
          AvatarAccessory(id: 4, code: 'APRON', name: '앞치마', requiredLevel: 2),
          AvatarAccessory(
            id: 5,
            code: 'EXPLORER_HAT',
            name: '탐험가 모자',
            requiredLevel: 3,
            unlocked: false,
          ),
        ],
      );

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
  Future<RewardHistory> fetchRewards() async =>
      const RewardHistory(titles: [], profileItems: []);

  @override
  Future<TitleCollection> fetchTitles() async => const TitleCollection(
    titles: [
      UserTitle(id: 1, name: '새내기 모험가'),
      UserTitle(id: 2, name: '동네 탐험가'),
    ],
    representativeTitleId: 1,
  );
}

class _FakeLifedexRepository extends LifedexRepository {
  _FakeLifedexRepository() : super(Dio());

  @override
  Future<LifedexOverview> fetchOverview() async => const LifedexOverview(
    categories: [
      LifedexCategory(id: 1, name: '카페', totalCount: 50, ownedCount: 20),
      LifedexCategory(id: 2, name: '공원', totalCount: 50, ownedCount: 22),
    ],
  );
}

class _FakeAchievementRepository extends AchievementRepository {
  _FakeAchievementRepository() : super(Dio());

  @override
  Future<AchievementOverview> fetchOverview() async =>
      const AchievementOverview(
        achievements: [
          Achievement(id: 1, name: '첫걸음', achieved: true, secret: false),
          Achievement(id: 2, name: '카페 탐험가 I', achieved: false, secret: false),
          Achievement(id: 3, name: '???', achieved: false, secret: true),
        ],
      );
}
