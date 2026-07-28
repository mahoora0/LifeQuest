import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:life_quest/app/life_quest_app.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/auth/application/auth_controller.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/data/quest_repository.dart';
import 'package:life_quest/features/profile/presentation/profile_screen.dart';
import 'package:life_quest/features/profile/presentation/profile_edit_screen.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
import 'package:life_quest/features/user/data/user_dto.dart';
import 'package:life_quest/features/user/data/user_repository.dart';

void main() {
  setUpAll(() {
    // 테스트에서 폰트를 내려받지 않는다(네트워크 의존 제거).
    GoogleFonts.config.allowRuntimeFetching = false;
  });

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
    expect(find.text('LifeDex'), findsOneWidget);
    expect(find.text('마이'), findsOneWidget);

    // 친구 탭은 Phase 2로 미뤄 라우트를 등록하지 않는다.
    expect(find.text('친구'), findsNothing);
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

  testWidgets('프로필 수정은 URL 입력 대신 사진 선택과 캐릭터 목록을 보여준다', (tester) async {
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
    expect(find.text('내 캐릭터'), findsOneWidget);
    expect(find.text('루키'), findsOneWidget);
    expect(find.text('모각'), findsOneWidget);
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
  ];

  @override
  Future<BadgeCollection> fetchBadges() async =>
      const BadgeCollection(badges: [], representativeBadgeId: null);

  @override
  Future<RewardHistory> fetchRewards() async =>
      const RewardHistory(titles: [], profileItems: []);
}
