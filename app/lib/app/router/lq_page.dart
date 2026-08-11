import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 축하 화면 전용 전환 — 겹쳐 흐리기만 한다.
///
/// **일반 push 라우트에는 쓰지 않는다.** `CustomTransitionPage`는 `PageRoute`를
/// 직접 상속해 `PageTransitionsTheme`을 우회하므로, 여기에 태우면
/// iOS 가장자리 스와이프 뒤로가기와 Android predictive back 미리보기가 사라진다.
/// 전환 모양을 통일하려고 앱 전체를 이쪽으로 옮겼다가 되돌린 이력이 있다
/// (`10-motion-plan.md` P1 회고).
///
/// 그래서 남은 자리는 하나다 — 퀘스트 완료 결과처럼 **뒤로 스와이프할 일이 없고
/// 연출이 곧 내용인 화면**. 밀려 들어오면 축하가 아니라 이동으로 읽힌다.
Page<void> lqCelebrationPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  final duration = LqMotion.of(context, LqMotion.normal);
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: LqMotion.standard,
            reverseCurve: LqMotion.exit,
          ),
          child: child,
        ),
    child: child,
  );
}
