import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 탭 밖 push 라우트의 화면 전환.
///
/// 화면 폭을 통째로 밀지 않고 아래에서 2%만 올라오며 겹쳐 흐린다. 밀어내기는
/// 이 앱처럼 카드가 겹겹이 쌓인 화면에서 종이가 옆으로 미끄러지는 것처럼 읽힌다.
/// 나올 때가 들어갈 때보다 빨라야 되돌아오는 길이 가볍다([LqMotion.pageReverse]).
///
/// 전환을 통째로 되돌려야 하면 이 함수 안에서 [MaterialPage]를 반환하면 된다 —
/// 라우트 30여 개를 다시 손대지 않기 위해 진입점을 하나로 둔 것이다.
Page<void> lqPage(BuildContext context, GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: LqMotion.of(context, LqMotion.page),
    reverseTransitionDuration: LqMotion.of(context, LqMotion.pageReverse),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: LqMotion.standard,
        reverseCurve: LqMotion.exit,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    child: child,
  );
}
