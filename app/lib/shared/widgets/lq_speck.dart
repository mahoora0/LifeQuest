import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 둥실 떠다니는 장식 조각(시안의 `lqFloat`).
///
/// 축하·안내 화면의 여백을 채우는 용도라 포인터를 받지 않는다.
/// 시안이 정한 장식 애니메이션은 이것과 위치 펄스([LqPulseRing]) 둘뿐이다.
///
/// > 이 위젯이 든 화면은 애니메이션이 끝나지 않으므로 위젯 테스트에서
/// > `pumpAndSettle()`이 타임아웃한다. `pump()` 또는 `pump(Duration(...))`을 쓸 것.
class LqSpeck extends StatefulWidget {
  const LqSpeck({
    super.key,
    required this.color,
    this.size = 10,
    this.angleDegrees = 0,
    this.shape = BoxShape.circle,
    this.duration = const Duration(milliseconds: 2800),
    this.delay = Duration.zero,
  });

  final Color color;
  final double size;
  final double angleDegrees;
  final BoxShape shape;
  final Duration duration;

  /// 여러 조각이 같은 박자로 움직이면 기계처럼 보인다.
  final Duration delay;

  @override
  State<LqSpeck> createState() => _LqSpeckState();
}

class _LqSpeckState extends State<LqSpeck> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  /// 시작 지연 타이머. 위젯이 먼저 사라지면 반드시 끊어야 한다 —
  /// 남겨 두면 위젯 테스트가 `!timersPending`으로 실패해 이 화면을 아예 검증할 수 없다.
  Timer? _startDelay;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.repeat(reverse: true);
    } else {
      _startDelay = Timer(widget.delay, () {
        if (mounted) _controller.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    _startDelay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -9 * _controller.value),
          child: child,
        ),
        child: Transform.rotate(
          angle: widget.angleDegrees * math.pi / 180,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: widget.shape,
              borderRadius: widget.shape == BoxShape.rectangle
                  ? BorderRadius.circular(3)
                  : null,
              border: Border.all(
                color: LqColors.ink,
                width: LqShape.borderWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
