import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 한 화면의 여러 요소가 **하나의 시간표**를 나눠 갖는 연출.
///
/// 요소마다 `TweenAnimationBuilder`를 따로 두면 시간표가 코드 여기저기로
/// 흩어져, 순서를 바꾸려면 값을 전부 다시 계산해야 한다. 여기서는 컨트롤러
/// 하나를 흘려보내고 각 요소가 `0~1` 구간([LqTimelineStep])만 지정한다.
///
/// 축하처럼 **순서 자체가 내용인 화면**에 쓴다. 일반 화면의 등장은
/// `LqStagger`로 충분하다.
class LqTimeline extends StatefulWidget {
  const LqTimeline({
    super.key,
    required this.duration,
    required this.child,
    this.delay = Duration.zero,
  });

  /// 시간표 전체 길이. 각 단계의 `start`·`end`가 이 길이를 나눠 쓴다.
  final Duration duration;

  /// 화면이 자리를 잡고 나서 시작하고 싶을 때.
  final Duration delay;

  final Widget child;

  /// 상위에 시간표가 있으면 그 진행도를 준다. 없으면 null —
  /// 그 경우 각 요소는 최종 상태로 그려진다.
  static Animation<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_LqTimelineScope>()?.animation;

  @override
  State<LqTimeline> createState() => _LqTimelineState();
}

class _LqTimelineState extends State<LqTimeline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // 동작 줄이기를 켰으면 연출을 건너뛰고 결과만 보여준다. 축하를 못 보는 것보다
    // 어지러운 쪽이 나쁘다.
    if (LqMotion.isReduced(context)) {
      _controller.value = 1;
      return;
    }

    _controller.duration = widget.duration;
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _LqTimelineScope(animation: _controller, child: widget.child);
}

class _LqTimelineScope extends InheritedWidget {
  const _LqTimelineScope({required this.animation, required super.child});

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_LqTimelineScope oldWidget) =>
      oldWidget.animation != animation;
}

/// 시간표의 [start]~[end] 구간에 등장하는 요소.
///
/// 값은 전체 길이에 대한 비율(0~1)이다. 구간이 겹쳐야 자연스럽다 —
/// 앞 요소가 끝난 뒤에 다음이 시작하면 뚝뚝 끊겨 보인다.
class LqTimelineStep extends StatelessWidget {
  const LqTimelineStep({
    super.key,
    required this.start,
    required this.end,
    required this.child,
    this.from = const Offset(0, 16),
    this.fromScale = 1,
    this.curve = LqMotion.arrive,
  });

  final double start;
  final double end;

  /// 시작 위치(최종 위치 기준 상대 px).
  final Offset from;

  /// 시작 크기. 도장처럼 찍히는 요소는 1보다 작게 두고 [curve]를
  /// [LqMotion.bounce]로 준다.
  final double fromScale;

  final Curve curve;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final timeline = LqTimeline.maybeOf(context);
    if (timeline == null) return child;

    return AnimatedBuilder(
      animation: timeline,
      builder: (context, child) {
        final t = Interval(start, end, curve: curve).transform(timeline.value);
        return Opacity(
          // 바운스는 1을 넘겼다 돌아오므로 불투명도만 잘라 준다.
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: from * (1 - t),
            child: fromScale == 1
                ? child
                : Transform.scale(
                    scale: lerpDouble(fromScale, 1, t),
                    child: child,
                  ),
          ),
        );
      },
      child: child,
    );
  }
}

/// 시간표를 따라 0에서 [value]까지 세어 올라가는 숫자.
///
/// 보상은 "얼마 받았다"는 사실보다 **받는 과정**이 기억에 남는다. 결과값이
/// 그냥 찍혀 있으면 읽고 지나가지만, 세어 올라가면 눈이 따라간다.
class LqCountUp extends StatelessWidget {
  const LqCountUp({
    super.key,
    required this.value,
    required this.builder,
    this.start = 0,
    this.end = 1,
  });

  final int value;
  final double start;
  final double end;
  final Widget Function(BuildContext context, int value) builder;

  @override
  Widget build(BuildContext context) {
    final timeline = LqTimeline.maybeOf(context);
    if (timeline == null) return builder(context, value);

    return AnimatedBuilder(
      animation: timeline,
      builder: (context, _) {
        final t = Interval(
          start,
          end,
          curve: LqMotion.standard,
        ).transform(timeline.value);
        return builder(context, (value * t).round());
      },
    );
  }
}
