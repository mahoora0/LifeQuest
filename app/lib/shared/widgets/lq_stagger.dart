import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 화면에 처음 들어올 때 위에서부터 차례로 나타난다.
///
/// 전부 한꺼번에 나타나면 화면이 "펑" 하고 켜지고, 전부 시간차를 주면 아래쪽
/// 카드를 기다리게 된다. 그래서 [LqMotion.staggerMaxItems]번째까지만 늦추고
/// 그 뒤는 지연 없이 함께 나온다.
///
/// **길게 스크롤하는 목록에는 쓰지 않는다.** `ListView`가 항목을 재활용하므로
/// 스크롤해서 되돌아올 때마다 다시 날아온다. 화면 상단의 고정된 섹션에만 쓴다.
class LqStagger extends StatelessWidget {
  const LqStagger({super.key, required this.index, required this.child});

  /// 0부터 세는 등장 순서.
  final int index;
  final Widget child;

  /// [index]번째 항목이 기다리는 시간.
  static Duration delayFor(int index) =>
      LqMotion.staggerStep *
      (index >= LqMotion.staggerMaxItems ? 0 : index).toDouble();

  /// 한 항목이 나타나는 데 걸리는 시간.
  ///
  /// 교체가 아니라 첫 등장이므로 [LqMotion.normal]보다 짧아도 된다. 마지막
  /// 항목까지 걸리는 총 시간(지연 200 + 160 = 360ms)을 400ms 아래로 붙잡는
  /// 것이 이 선택의 이유다.
  static const itemDuration = LqMotion.quick;

  @override
  Widget build(BuildContext context) {
    // 동작 줄이기를 켠 사람에게는 순서대로 나타나는 것 자체가 방해다.
    if (LqMotion.isReduced(context)) return child;

    final delay = delayFor(index);
    final total = delay + itemDuration;
    final start = delay.inMicroseconds / total.inMicroseconds;

    // 타이머 대신 Interval로 기다린다. TweenAnimationBuilder는 end가 바뀔 때만
    // 다시 도므로, 같은 값으로 rebuild되는 동안에는 재생되지 않는다.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: LqMotion.standard),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
