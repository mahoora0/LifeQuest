import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/app/router/lq_page.dart';
import 'package:life_quest/app/router/navigation_shell.dart';
import 'package:life_quest/features/auth/application/auth_controller.dart';
import 'package:life_quest/features/auth/presentation/auth_splash_screen.dart';
import 'package:life_quest/features/auth/presentation/login_screen.dart';
import 'package:life_quest/features/auth/presentation/signup_screen.dart';
import 'package:life_quest/features/achievement/presentation/achievement_screen.dart';
import 'package:life_quest/features/friends/presentation/friend_journey_screen.dart';
import 'package:life_quest/features/friends/presentation/friend_requests_screen.dart';
import 'package:life_quest/features/friends/presentation/friend_search_screen.dart';
import 'package:life_quest/features/friends/presentation/friends_screen.dart';
import 'package:life_quest/features/home/presentation/home_screen.dart';
import 'package:life_quest/features/group/presentation/group_chat_screen.dart';
import 'package:life_quest/features/group/presentation/group_detail_screen.dart';
import 'package:life_quest/features/group/presentation/group_form_screen.dart';
import 'package:life_quest/features/group/presentation/group_invitations_screen.dart';
import 'package:life_quest/features/group/presentation/group_join_requests_screen.dart';
import 'package:life_quest/features/group/presentation/group_list_screen.dart';
import 'package:life_quest/features/group/presentation/group_members_screen.dart';
import 'package:life_quest/features/group/presentation/group_quest_detail_screen.dart';
import 'package:life_quest/features/group/presentation/group_quest_form_screen.dart';
import 'package:life_quest/features/group/presentation/group_search_screen.dart';
import 'package:life_quest/features/lifedex/presentation/lifedex_screen.dart';
import 'package:life_quest/features/location/presentation/location_consent_screen.dart';
import 'package:life_quest/features/notification/presentation/notification_screen.dart';
import 'package:life_quest/features/profile/presentation/profile_screen.dart';
import 'package:life_quest/features/profile/presentation/profile_edit_screen.dart';
import 'package:life_quest/features/profile/presentation/character_selection_screen.dart';
import 'package:life_quest/features/proof/presentation/proof_detail_screen.dart';
import 'package:life_quest/features/proof/presentation/proof_feed_screen.dart';
import 'package:life_quest/features/proof/presentation/proof_form_args.dart';
import 'package:life_quest/features/proof/presentation/proof_form_screen.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/presentation/map_screen.dart';
import 'package:life_quest/features/quest/presentation/quest_detail_screen.dart';
import 'package:life_quest/features/quest/presentation/quest_list_screen.dart';
import 'package:life_quest/features/quest/presentation/quest_result_screen.dart';
import 'package:life_quest/features/quest/presentation/quest_route_args.dart';
import 'package:life_quest/features/quest/presentation/quest_verify_screen.dart';
import 'package:life_quest/features/reward/presentation/reward_screen.dart';
import 'package:life_quest/features/recommendation/data/quest_recommendation_dto.dart';
import 'package:life_quest/features/recommendation/presentation/place_recommendation_form_screen.dart';
import 'package:life_quest/features/recommendation/presentation/recommendation_result_screen.dart';
import 'package:life_quest/features/recommendation/presentation/recommendation_type_screen.dart';
import 'package:life_quest/features/recommendation/presentation/travel_recommendation_form_screen.dart';
import 'package:life_quest/shared/presentation/feature_placeholder_screen.dart';

/// 탭 구성은 시안 확정안을 따른다: 홈 · 퀘스트 · 지도 · 친구 · 마이.
///
/// LifeDex 도감(S-13)과 업적·칭호(S-15)는 탭에서 빠지고 마이페이지 "나의 기록" 카드에서
/// push로 연다. 탭 밖 라우트라 하단 탭바가 가려지고 좌상단 ←로 돌아온다.
final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  // 인증 상태 변경으로 GoRouter가 다시 생성될 때 이전 Router와 같은 전역
  // NavigatorKey를 공유하면 한 프레임 안에서 키가 중복 예약될 수 있다.
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final location = state.matchedLocation;
      final session = auth.value;
      if (auth.isLoading && session == null) {
        return location == '/splash' ? null : '/splash';
      }

      final isAuthenticated = session == AuthSession.authenticated;
      final isAuthRoute = location == '/login' || location == '/signup';
      if (!isAuthenticated) {
        return isAuthRoute ? null : '/login';
      }
      if (isAuthRoute || location == '/splash') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const AuthSplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            NavigationShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/quests',
                // `?tab=weekly`로 주간 탭을 지정해 들어올 수 있다. AI 퀘스트를
                // 받은 직후 목록으로 돌아올 때 일간 탭이 뜨면 방금 받은 퀘스트가
                // 보이지 않아 실패한 것처럼 읽힌다.
                builder: (context, state) => QuestListScreen(
                  initialTab: state.uri.queryParameters['tab'],
                ),
              ),
            ],
          ),
          // 세 번째 탭은 지도에서 그룹으로 바뀌었다. 그룹 목록만 탭 브랜치에 두고
          // 하위 화면(`/groups/...`)은 그대로 push 라우트로 남긴다 — 상세·채팅에서
          // 하단 탭바가 사라지는 지금 동작을 유지하기 위해서다.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/groups',
                builder: (context, state) => const GroupListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/friends',
                builder: (context, state) => const FriendsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // --- 탭 밖 push 라우트 (하단 탭바 숨김) ---

      // 인증 광장. LifeDex·업적과 같은 이유로 탭에 넣지 않는다 —
      // 탭 구성은 시안 확정안(홈·퀘스트·지도·친구·마이)이라 늘리지 않고,
      // 홈의 "인증 광장" 섹션에서 push로 연다.
      //
      // `/proofs/new`를 `/proofs/:postId`보다 먼저 선언해야
      // "new"가 postId로 잡히지 않는다.
      GoRoute(
        path: '/proofs',
        builder: (context, state) => const ProofFeedScreen(),
      ),
      GoRoute(
        path: '/proofs/new',
        builder: (context, state) => ProofFormScreen(
          // 퀘스트 완료 결과 화면에서 넘어오면 완료 기록이 이미 정해져 있다.
          // 피드의 + 버튼으로 들어오면 extra가 없어 목록에서 고른다.
          args: state.extra is ProofFormArgs
              ? state.extra! as ProofFormArgs
              : null,
        ),
      ),
      GoRoute(
        path: '/proofs/:postId',
        builder: (context, state) => ProofDetailScreen(
          postId: int.tryParse(state.pathParameters['postId'] ?? '') ?? 0,
        ),
      ),

      // `/quests/result`를 `/quests/:questId`보다 먼저 선언해야
      // "result"가 questId로 잡히지 않는다.
      // 앱에서 유일하게 커스텀 전환을 쓰는 라우트. 축하는 밀려 들어오는 것보다
      // 겹쳐 떠오르는 쪽이 맞고, 이 화면은 뒤로 스와이프할 일이 없다.
      GoRoute(
        path: '/quests/result',
        pageBuilder: (context, state) {
          final result = state.extra;
          return lqCelebrationPage(
            context,
            state,
            result is QuestCompletionResult
                ? QuestResultScreen(result: result)
                : const FeaturePlaceholderScreen(
                    title: '퀘스트 완료',
                    message: '완료 결과를 불러오지 못했어요',
                  ),
          );
        },
      ),
      GoRoute(
        path: '/quests/:questId',
        builder: (context, state) => QuestDetailScreen(
          questId: int.tryParse(state.pathParameters['questId'] ?? '') ?? 0,
          args: state.extra is QuestDetailArgs
              ? state.extra! as QuestDetailArgs
              : null,
        ),
      ),
      GoRoute(
        path: '/quests/:dailyQuestId/verify',
        builder: (context, state) {
          final args = state.extra;
          if (args is! QuestVerifyArgs) {
            return const FeaturePlaceholderScreen(
              title: '위치 인증',
              message: '퀘스트 정보를 불러오지 못했어요',
              hint: '퀘스트 상세에서 다시 시도해 주세요.',
            );
          }
          return QuestVerifyScreen(
            dailyQuestId:
                int.tryParse(state.pathParameters['dailyQuestId'] ?? '') ?? 0,
            quest: args.quest,
          );
        },
      ),
      // `/friends/search`·`/friends/requests`를 `/friends/:userId`보다 먼저
      // 선언해야 "search"가 userId로 잡히지 않는다.
      GoRoute(
        path: '/friends/search',
        builder: (context, state) => const FriendSearchScreen(),
      ),
      GoRoute(
        path: '/friends/requests',
        builder: (context, state) => const FriendRequestsScreen(),
      ),
      GoRoute(
        path: '/friends/:userId',
        builder: (context, state) => FriendJourneyScreen(
          userId: int.tryParse(state.pathParameters['userId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/lifedex',
        builder: (context, state) => const LifedexScreen(),
      ),
      GoRoute(
        path: '/achievements',
        builder: (context, state) => AchievementScreen(
          initialTab: switch (state.uri.queryParameters['tab']) {
            'titles' => 1,
            _ => 0,
          },
        ),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/profile/character',
        builder: (context, state) => const CharacterSelectionScreen(),
      ),
      // 마이페이지의 EXP 바를 눌러 연다. 값이 이미 보이는 자리를 누르는 쪽이
      // "나의 기록"에 행을 하나 더 붙이는 것보다 예측 가능하다.
      GoRoute(
        path: '/rewards',
        builder: (context, state) => const RewardScreen(),
      ),
      // 위치 권한 전면 안내(1단계). 홈이 첫 프레임 뒤에 실행당 한 번 push한다.
      GoRoute(
        path: '/location-consent',
        builder: (context, state) => const LocationConsentScreen(),
      ),
      // 홈의 벨은 기록 전용, 마이페이지의 알림 설정은 설정 전용 화면으로 연다.
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) =>
            const NotificationScreen(mode: NotificationScreenMode.settings),
      ),
      // 지도. 탭에서 빠져 지금은 여기로 들어오는 화면이 없다 — 화면과 라우트는
      // 남겨 두고, 다시 필요해지면 진입점만 붙이면 된다.
      GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
      GoRoute(
        path: '/groups/search',
        builder: (context, state) => const GroupSearchScreen(),
      ),
      GoRoute(
        path: '/groups/create',
        builder: (context, state) => const GroupFormScreen(),
      ),
      GoRoute(
        path: '/groups/invitations',
        builder: (context, state) => const GroupInvitationsScreen(),
      ),
      GoRoute(
        path: '/groups/:groupId/edit',
        builder: (context, state) => GroupFormScreen(
          groupId: int.tryParse(state.pathParameters['groupId'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/groups/:groupId/members',
        builder: (context, state) => GroupMembersScreen(
          groupId: int.tryParse(state.pathParameters['groupId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/groups/:groupId/join-requests',
        builder: (context, state) => GroupJoinRequestsScreen(
          groupId: int.tryParse(state.pathParameters['groupId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/groups/:groupId/chat',
        builder: (context, state) => GroupChatScreen(
          groupId: int.tryParse(state.pathParameters['groupId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/groups/:groupId/quests/create',
        builder: (context, state) => GroupQuestFormScreen(
          groupId: int.tryParse(state.pathParameters['groupId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/groups/:groupId/quests/:questId/edit',
        builder: (context, state) => GroupQuestFormScreen(
          groupId: int.tryParse(state.pathParameters['groupId'] ?? '') ?? 0,
          questId: int.tryParse(state.pathParameters['questId'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/groups/:groupId/quests/:questId',
        builder: (context, state) => GroupQuestDetailScreen(
          groupId: int.tryParse(state.pathParameters['groupId'] ?? '') ?? 0,
          questId: int.tryParse(state.pathParameters['questId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/groups/:groupId',
        builder: (context, state) => GroupDetailScreen(
          groupId: int.tryParse(state.pathParameters['groupId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/quest-recommendations',
        builder: (context, state) =>
            RecommendationTypeScreen(weekly: _isWeekly(state)),
      ),
      GoRoute(
        path: '/quest-recommendations/place',
        builder: (context, state) =>
            PlaceRecommendationFormScreen(weekly: _isWeekly(state)),
      ),
      GoRoute(
        path: '/quest-recommendations/travel',
        builder: (context, state) =>
            TravelRecommendationFormScreen(weekly: _isWeekly(state)),
      ),
      GoRoute(
        path: '/quest-recommendations/result',
        builder: (context, state) => state.extra is QuestRecommendationResult
            ? RecommendationResultScreen(
                result: state.extra! as QuestRecommendationResult,
              )
            : const FeaturePlaceholderScreen(
                title: '추천 결과',
                message: '추천 결과를 불러오지 못했어요',
              ),
      ),
    ],
  );
});

/// `?weekly=true`면 주간 퀘스트 슬롯용 추천이다.
///
/// 일반 추천과 경로가 갈리는 이유는 서버 계약이 다르기 때문이다 — 주간 쪽만
/// Lv.3 잠금과 그 주의 남은 기간 제한이 걸리고, 후보도 그쪽에서만 저장된다.
bool _isWeekly(GoRouterState state) =>
    state.uri.queryParameters['weekly'] == 'true';
