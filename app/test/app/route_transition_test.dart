import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/app/router/app_router.dart';
import 'package:life_quest/app/router/lq_page.dart';
import 'package:life_quest/features/auth/application/auth_controller.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 화면 전환 통일(`10-motion-plan.md` P1).
///
/// 전환이 "부드러운지"가 아니라 **어떤 라우트가 어떤 전환을 쓰는지**와
/// **전환 중 트리 상태**를 고정한다.
void main() {
  group('lqPage', () {
    testWidgets('들어갈 때보다 나올 때가 빠르다', (tester) async {
      late Page<void> page;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const Text('첫 화면')),
          GoRoute(
            path: '/next',
            pageBuilder: (context, state) =>
                page = lqPage(context, state, const Text('다음 화면')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.go('/next');
      await tester.pumpAndSettle();

      final transition = page as CustomTransitionPage<void>;
      expect(transition.transitionDuration, LqMotion.page);
      expect(transition.reverseTransitionDuration, LqMotion.pageReverse);
      // 되돌아오는 길이 무거우면 앱이 굼떠 보인다.
      expect(
        transition.reverseTransitionDuration,
        lessThan(transition.transitionDuration),
      );
    });

    testWidgets('전환 중에는 두 화면이 겹쳐 있고 끝나면 이전 화면이 사라진다', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const Text('첫 화면')),
          GoRoute(
            path: '/next',
            pageBuilder: (context, state) =>
                lqPage(context, state, const Text('다음 화면')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      expect(find.text('첫 화면'), findsOneWidget);

      router.go('/next');
      await tester.pump();
      // 전환 한가운데.
      await tester.pump(LqMotion.page ~/ 2);
      expect(find.text('첫 화면'), findsOneWidget);
      expect(find.text('다음 화면'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('첫 화면'), findsNothing);
      expect(find.text('다음 화면'), findsOneWidget);
    });

    testWidgets('겹쳐 흐리며 아래에서 올라온다', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const Text('첫 화면')),
          GoRoute(
            path: '/next',
            pageBuilder: (context, state) =>
                lqPage(context, state, const Text('다음 화면')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.go('/next');
      await tester.pump();
      await tester.pump(LqMotion.page ~/ 3);

      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('다음 화면'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, greaterThan(0));
      expect(fade.opacity.value, lessThan(1));

      final slide = tester.widget<SlideTransition>(
        find
            .ancestor(
              of: find.text('다음 화면'),
              matching: find.byType(SlideTransition),
            )
            .first,
      );
      // 화면 폭을 통째로 밀지 않는다. 아래에서 아주 조금 올라온다.
      expect(slide.position.value.dx, 0);
      expect(slide.position.value.dy, greaterThan(0));
      expect(slide.position.value.dy, lessThan(0.02));

      await tester.pumpAndSettle();
    });
  });

  group('앱 라우터', () {
    /// 라우터만 만든다 — 화면은 짓지 않으므로 저장소 override가 필요 없다.
    GoRouter buildRouter() {
      final container = ProviderContainer(
        overrides: [
          storedAuthSessionProvider.overrideWith(
            (ref) async => AuthSession.authenticated,
          ),
        ],
      );
      addTearDown(container.dispose);
      return container.read(appRouterProvider);
    }

    Iterable<GoRoute> allRoutes(List<RouteBase> routes) sync* {
      for (final route in routes) {
        if (route is GoRoute) yield route;
        yield* allRoutes(route.routes);
        if (route is StatefulShellRoute) {
          for (final branch in route.branches) {
            yield* allRoutes(branch.routes);
          }
        }
      }
    }

    GoRoute routeAt(GoRouter router, String path) => allRoutes(
      router.configuration.routes,
    ).firstWhere((route) => route.path == path);

    test('탭 밖 push 라우트는 커스텀 전환을 쓴다', () {
      final router = buildRouter();
      for (final path in const [
        '/proofs',
        '/proofs/:postId',
        '/quests/:questId',
        '/lifedex',
        '/achievements',
        '/profile/edit',
        '/groups/:groupId',
        '/quest-recommendations',
      ]) {
        expect(
          routeAt(router, path).pageBuilder,
          isNotNull,
          reason: '$path는 lqPage 전환을 써야 한다',
        );
      }
    });

    test('인증 라우트와 탭 브랜치에는 전환을 넣지 않는다', () {
      final router = buildRouter();
      // 리다이렉트로 자동 전환되는 자리에 전환을 넣으면 앱 시작이 굼떠 보인다.
      for (final path in const ['/splash', '/login', '/signup']) {
        expect(routeAt(router, path).pageBuilder, isNull, reason: path);
      }
      // 탭 이동은 push가 아니라 브랜치 전환이다(fade through는 셸이 맡는다).
      for (final path in const ['/', '/quests', '/groups', '/friends']) {
        expect(routeAt(router, path).pageBuilder, isNull, reason: path);
      }
    });
  });
}
