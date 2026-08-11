import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 옆으로 끌어 실행하는 동작.
///
/// 손가락을 1:1로 따라오고, 놓으면 스프링으로 정착한다. 탭은 눌렀다는 사실만
/// 남기지만 끌기는 **얼마나 갔는지가 계속 보이므로**, 도중에 마음을 바꿔
/// 되돌릴 수 있다. 앱이 살아 있다고 느끼는 대부분이 이 종류의 반응이다.
///
/// 애니메이션 중에 다시 잡으면 그 지점에서 이어받는다([AnimationController.stop]) —
/// 되돌아가는 중인 행을 다시 끌 수 없으면 조작이 미끄러진다.
class LqSwipeAction extends StatefulWidget {
  const LqSwipeAction({
    super.key,
    required this.child,
    required this.onCommit,
    this.enabled = true,
    this.threshold = 84,
    this.maxDrag = 116,
    this.background,
    this.semanticLabel,
  });

  final Widget child;

  /// 임계값을 넘겨 놓았을 때 한 번 호출된다.
  final VoidCallback onCommit;

  final bool enabled;

  /// 이만큼 끌고 놓으면 실행된다.
  final double threshold;

  /// 더 끌어도 여기서 멈춘다. 끝없이 밀리면 무엇이 일어날지 알 수 없다.
  final double maxDrag;

  /// 행 뒤에서 드러나는 배경. 진행도(0~1)를 받는다.
  final Widget Function(BuildContext context, double progress)? background;

  /// 끌기를 대신할 접근성 동작 이름.
  ///
  /// 끌기는 스크린 리더 사용자가 쓸 수 없는 조작이라, 같은 일을 하는 사용자 정의
  /// 동작을 함께 등록한다.
  final String? semanticLabel;

  @override
  State<LqSwipeAction> createState() => _LqSwipeActionState();
}

class _LqSwipeActionState extends State<LqSwipeAction>
    with SingleTickerProviderStateMixin {
  /// `late final`로 두면 안 된다. 끌 수 없는 행([LqSwipeAction.enabled]가 false)은
  /// 컨트롤러를 한 번도 건드리지 않는데, 그러면 `dispose()`에서 **처음 생성되면서**
  /// 이미 비활성인 위젯의 조상(TickerMode)을 찾다가 죽는다.
  late final AnimationController _dx;

  @override
  void initState() {
    super.initState();
    _dx = AnimationController.unbounded(vsync: this);
  }

  @override
  void dispose() {
    _dx.dispose();
    super.dispose();
  }

  void _settle(double velocity) {
    // Material 3 Expressive의 공간 스프링. 살짝 넘겼다 자리를 잡는다.
    _dx.animateWith(
      SpringSimulation(LqMotion.spatialSpring, _dx.value, 0, velocity),
    );
  }

  void _onEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (_dx.value >= widget.threshold) {
      // 손끝에서 확정됐다는 신호를 먼저 준다. 화면보다 손이 빠르다.
      HapticFeedback.lightImpact();
      widget.onCommit();
    }
    _settle(velocity);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || LqMotion.isReduced(context)) return widget.child;

    final label = widget.semanticLabel;
    final gesture = GestureDetector(
      // 세로 스크롤을 가로채지 않도록 가로 끌기만 듣는다.
      onHorizontalDragStart: (_) => _dx.stop(),
      onHorizontalDragUpdate: (details) {
        _dx.value = (_dx.value + details.delta.dx).clamp(0.0, widget.maxDrag);
      },
      onHorizontalDragEnd: _onEnd,
      onHorizontalDragCancel: () => _settle(0),
      child: AnimatedBuilder(
        animation: _dx,
        builder: (context, child) {
          final progress = (_dx.value / widget.threshold).clamp(0.0, 1.0);
          return Stack(
            children: [
              if (widget.background != null && _dx.value > 0)
                Positioned.fill(child: widget.background!(context, progress)),
              Transform.translate(offset: Offset(_dx.value, 0), child: child),
            ],
          );
        },
        child: widget.child,
      ),
    );

    if (label == null) return gesture;
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: label): widget.onCommit,
      },
      child: gesture,
    );
  }
}
