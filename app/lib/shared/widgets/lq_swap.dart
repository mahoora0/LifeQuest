import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 값이 바뀔 때 겹쳐 흐리며 교체한다.
///
/// 레벨·EXP처럼 오르는 순간 자체가 보상인 숫자에 쓴다. 숫자가 딱 갈아끼워지면
/// 값이 바뀐 줄도 모르고 지나간다.
///
/// [value]가 곧 `ValueKey`다 — 이걸 빼먹으면 `AnimatedSwitcher`는 같은 위젯으로
/// 보고 아무 일도 하지 않는다. 그 실수를 막으려고 별도 위젯으로 뒀다.
class LqSwap extends StatelessWidget {
  const LqSwap({super.key, required this.value, required this.child});

  final Object value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: LqMotion.of(context, LqMotion.normal),
      switchInCurve: LqMotion.standard,
      switchOutCurve: LqMotion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          // 0.8처럼 크게 잡으면 숫자가 튀어나오는 장난감이 된다.
          scale: Tween<double>(begin: 0.97, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey<Object>(value), child: child),
    );
  }
}
