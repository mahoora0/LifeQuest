import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/app/life_quest_app.dart';
import 'package:life_quest/app/router/app_router.dart';
import 'package:life_quest/app/router/lq_page.dart';
import 'package:life_quest/features/auth/application/auth_controller.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 화면 전환 정책.
///
/// 한 번 앱 전체를 `CustomTransitionPage`로 옮겼다가 되돌렸다 — 그 경로는
/// `PageTransitionsTheme`을 우회해 iOS 스와이프 뒤로가기와 Android predictive
/// back을 잃는다. 그 회귀가 다시 들어오지 못하게 막는 것이 이 파일의 목적이다.
void main() {
  group('전환 정책', () {
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

    test('커스텀 전환을 쓰는 라우트는 축하 화면 하나뿐이다', () {
      final router = buildRouter();
      final custom = allRoutes(router.configuration.routes)
          .where((route) => route.pageBuilder != null)
          .map((route) => route.path)
          .toList();

      // 늘리려면 그 화면에서 스와이프 뒤로가기를 포기해도 되는지 먼저 따진다.
      expect(custom, ['/quests/result']);
    });

    test('플랫폼 전환을 테마에 명시해 둔다', () {
      final builders = buildLifeQuestTheme().pageTransitionsTheme.builders;

      expect(
        builders[TargetPlatform.android],
        isA<PredictiveBackPageTransitionsBuilder>(),
      );
      // iOS 가장자리 스와이프 뒤로가기는 이 빌더가 제공한다.
      expect(
        builders[TargetPlatform.iOS],
        isA<CupertinoPageTransitionsBuilder>(),
      );
    });
  });

  group('lqCelebrationPage', () {
    testWidgets('밀지 않고 겹쳐 흐리기만 한다', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const Text('첫 화면')),
          GoRoute(
            path: '/next',
            pageBuilder: (context, state) =>
                lqCelebrationPage(context, state, const Text('축하 화면')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.go('/next');

      await tester.pump();
      await tester.pump(LqMotion.normal ~/ 2);

      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('축하 화면'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, greaterThan(0));
      expect(fade.opacity.value, lessThan(1));
      // 축하는 이동이 아니다 — 슬라이드를 붙이지 않는다.
      expect(
        find.ancestor(
          of: find.text('축하 화면'),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );

      await tester.pumpAndSettle();
      expect(find.text('첫 화면'), findsNothing);
    });
  });
}
