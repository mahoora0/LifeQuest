import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/app/router/navigation_shell.dart';
import 'package:life_quest/features/auth/application/auth_controller.dart';
import 'package:life_quest/features/auth/presentation/auth_splash_screen.dart';
import 'package:life_quest/features/auth/presentation/login_screen.dart';
import 'package:life_quest/features/auth/presentation/signup_screen.dart';
import 'package:life_quest/features/achievement/presentation/achievement_screen.dart';
import 'package:life_quest/features/friends/presentation/friends_screen.dart';
import 'package:life_quest/features/home/presentation/home_screen.dart';
import 'package:life_quest/features/lifedex/presentation/lifedex_screen.dart';
import 'package:life_quest/features/notification/presentation/notification_screen.dart';
import 'package:life_quest/features/profile/presentation/profile_screen.dart';
import 'package:life_quest/features/profile/presentation/profile_edit_screen.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/presentation/map_screen.dart';
import 'package:life_quest/features/quest/presentation/quest_detail_screen.dart';
import 'package:life_quest/features/quest/presentation/quest_list_screen.dart';
import 'package:life_quest/features/quest/presentation/quest_result_screen.dart';
import 'package:life_quest/features/quest/presentation/quest_route_args.dart';
import 'package:life_quest/features/quest/presentation/quest_verify_screen.dart';
import 'package:life_quest/features/reward/presentation/reward_screen.dart';
import 'package:life_quest/shared/presentation/feature_placeholder_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// 탭 구성은 시안 확정안을 따른다: 홈 · 퀘스트 · 지도 · 친구 · 마이.
///
/// LifeDex 도감(S-13)과 업적·칭호(S-15)는 탭에서 빠지고 마이페이지 "나의 기록" 카드에서
/// push로 연다. 탭 밖 라우트라 하단 탭바가 가려지고 좌상단 ←로 돌아온다.
final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
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
                builder: (context, state) => const QuestListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => const MapScreen(),
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
      // `/quests/result`를 `/quests/:questId`보다 먼저 선언해야
      // "result"가 questId로 잡히지 않는다.
      GoRoute(
        path: '/quests/result',
        builder: (context, state) {
          final result = state.extra;
          if (result is! QuestCompletionResult) {
            return const FeaturePlaceholderScreen(
              title: '퀘스트 완료',
              message: '완료 결과를 불러오지 못했어요',
            );
          }
          return QuestResultScreen(result: result);
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
      GoRoute(
        path: '/lifedex',
        builder: (context, state) => const LifedexScreen(),
      ),
      GoRoute(
        path: '/achievements',
        builder: (context, state) => AchievementScreen(
          initialTab: switch (state.uri.queryParameters['tab']) {
            'titles' => 1,
            'badges' => 2,
            _ => 0,
          },
        ),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const ProfileEditScreen(),
      ),
      // 마이페이지의 EXP 바를 눌러 연다. 값이 이미 보이는 자리를 누르는 쪽이
      // "나의 기록"에 행을 하나 더 붙이는 것보다 예측 가능하다.
      GoRoute(
        path: '/rewards',
        builder: (context, state) => const RewardScreen(),
      ),
      // 알림 목록은 홈 헤더의 벨에서, 설정은 마이페이지에서 연다. 설정 카드가
      // 목록 하단에 붙어 있으므로 두 진입점이 같은 화면으로 모인다.
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        redirect: (context, state) => '/notifications',
      ),
    ],
  );
});
