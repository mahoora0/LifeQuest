import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:life_quest/app/life_quest_app.dart';
import 'package:life_quest/features/achievement/application/achievement_providers.dart';
import 'package:life_quest/features/achievement/data/achievement_dto.dart';
import 'package:life_quest/features/auth/application/auth_controller.dart';
import 'package:life_quest/features/lifedex/application/lifedex_providers.dart';
import 'package:life_quest/features/lifedex/data/lifedex_dto.dart';
import 'package:life_quest/features/location/application/location_consent_controller.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/data/quest_repository.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
import 'package:life_quest/features/user/data/user_dto.dart';
import 'package:life_quest/features/user/data/user_repository.dart';
import 'package:life_quest/features/group/application/group_providers.dart';
import 'package:life_quest/features/group/data/group_dto.dart';
import 'package:life_quest/features/group/data/group_repository.dart';
import 'package:life_quest/features/recommendation/presentation/recommendation_type_screen.dart';

class _FakeLocationConsentNotifier extends LocationConsentNotifier {
  @override
  Future<LocationConsentStage> build() async => LocationConsentStage.granted;
}

class _FakeUserRepository extends UserRepository {
  final int userLevel;
  _FakeUserRepository({this.userLevel = 1}) : super(Dio());

  @override
  Future<UserProfile> fetchMe() async => const UserProfile(
    id: 1,
    nickname: '모험가',
    selectedCharacter: AvatarCharacter(
      id: 1,
      code: 'ROOKIE',
      name: '루키',
      assetKey: 'rookie.png',
    ),
  );

  @override
  Future<LevelStatus> fetchLevel() async => LevelStatus(
    level: userLevel,
    totalExp: 100,
    currentLevelExp: 10,
    nextLevelRequiredExp: 100,
  );

  @override
  Future<List<AvatarCharacter>> fetchCharacters() async => const [
    AvatarCharacter(id: 1, code: 'ROOKIE', name: '루키', assetKey: 'rookie.png'),
  ];

  @override
  Future<RewardHistory> fetchRewards() async =>
      const RewardHistory(titles: [], profileItems: []);

  @override
  Future<TitleCollection> fetchTitles() async => const TitleCollection(
    titles: [UserTitle(id: 1, name: '새내기 모험가')],
    representativeTitleId: 1,
  );
}

class _FakeQuestRepository extends QuestRepository {
  _FakeQuestRepository() : super(Dio());

  @override
  Future<TodayQuests> fetchToday({double? latitude, double? longitude}) async =>
      const TodayQuests(assignedDate: '2026-08-04', quests: []);
}

class _FakeGroupRepository extends GroupRepository {
  _FakeGroupRepository() : super(Dio());

  @override
  Future<List<GroupSummary>> myGroups() async => [
    const GroupSummary(
      id: 1,
      name: '주말 탐험대',
      description: '함께 탐험해요',
      activeMemberCount: 2,
      maxMembers: 10,
      joinable: true,
      myRole: GroupRole.owner,
      myMembershipStatus: GroupMembershipStatus.active,
      status: GroupStatus.active,
    ),
  ];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 실제 API 계약은 백엔드 통합 테스트에서 검증한다. 여기서는 iOS 앱 프로세스에서
  // 주요 라우트와 화면 조합이 정상 렌더링되는지 빠르게 확인한다.
  group('LifeQuest iOS Simulator App Smoke Tests', () {
    testWidgets('1. 로그인 화면 렌더링 검증', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storedAuthSessionProvider.overrideWith(
              (ref) async => AuthSession.unauthenticated,
            ),
            locationConsentProvider.overrideWith(
              _FakeLocationConsentNotifier.new,
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

    testWidgets('2. 레벨 1 계정 메인 화면 및 퀘스트 탭 해금 정책 검증', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storedAuthSessionProvider.overrideWith(
              (ref) async => AuthSession.authenticated,
            ),
            locationConsentProvider.overrideWith(
              _FakeLocationConsentNotifier.new,
            ),
            userRepositoryProvider.overrideWithValue(
              _FakeUserRepository(userLevel: 1),
            ),
            questRepositoryProvider.overrideWithValue(_FakeQuestRepository()),
            groupRepositoryProvider.overrideWithValue(_FakeGroupRepository()),
            lifedexOverviewProvider.overrideWith(
              (ref) async => const LifedexOverview(categories: []),
            ),
            achievementOverviewProvider.overrideWith(
              (ref) async => const AchievementOverview(achievements: []),
            ),
          ],
          child: const LifeQuestApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 메인 바텀 탭 확인
      expect(find.text('홈'), findsOneWidget);
      expect(find.text('퀘스트'), findsOneWidget);
      expect(find.text('지도'), findsOneWidget);
      expect(find.text('친구'), findsOneWidget);
      expect(find.text('마이'), findsOneWidget);

      // 퀘스트 탭 클릭 및 전환
      await tester.tap(find.text('퀘스트'));
      await tester.pumpAndSettle();

      // 일간/주간/협동 탭 렌더링 검증
      expect(find.text('일간'), findsOneWidget);
      expect(find.text('주간'), findsOneWidget);
      expect(find.text('협동'), findsOneWidget);
    });

    testWidgets('3. 마이페이지 진입 -> 내 그룹 선택 및 소모임 목록 검증', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storedAuthSessionProvider.overrideWith(
              (ref) async => AuthSession.authenticated,
            ),
            locationConsentProvider.overrideWith(
              _FakeLocationConsentNotifier.new,
            ),
            userRepositoryProvider.overrideWithValue(
              _FakeUserRepository(userLevel: 3),
            ),
            questRepositoryProvider.overrideWithValue(_FakeQuestRepository()),
            groupRepositoryProvider.overrideWithValue(_FakeGroupRepository()),
            lifedexOverviewProvider.overrideWith(
              (ref) async => const LifedexOverview(categories: []),
            ),
            achievementOverviewProvider.overrideWith(
              (ref) async => const AchievementOverview(achievements: []),
            ),
          ],
          child: const LifeQuestApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 마이 탭 클릭
      await tester.tap(find.text('마이'));
      await tester.pumpAndSettle();

      // 마이페이지 스크롤 다운
      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.fling(scrollable.first, const Offset(0, -600), 1000);
        await tester.pumpAndSettle();
      }

      // 내 그룹 메뉴 클릭
      await tester.tap(find.text('내 그룹'));
      await tester.pumpAndSettle();

      // 그룹 목록 및 생성/검색 버튼 검증
      expect(find.text('주말 탐험대'), findsOneWidget);
      expect(find.text('그룹 만들기'), findsOneWidget);
      expect(find.text('그룹 찾기'), findsOneWidget);
    });

    testWidgets('4. AI 퀘스트 추천 카테고리 선택 화면 렌더링 검증', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: RecommendationTypeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI 퀘스트 추천'), findsOneWidget);
      expect(find.text('장소 추천'), findsOneWidget);
      expect(find.text('여행 추천'), findsOneWidget);
    });
  });
}
