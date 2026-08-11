import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 누르는 동안의 물리감을 담당하는 래퍼.
///
/// 앱은 `NoSplash` + 투명 하이라이트를 쓰므로 Material의 잉크 효과가 없다.
/// 그 자리를 이 위젯이 대신한다 — 눌린 진행도 `t`(0=평상시, 1=눌림)를 넘겨
/// 표면이 자기 섀도를 [LqShape.pressShadow]로 줄이게 하고, 줄어든 만큼
/// [depth]로 내려앉힌다. 스티커가 종이에 눌러 붙는 연출이다.
///
/// 섀도를 직접 그리지 않는 이유는 위젯마다 섀도 값이 다르기 때문이다.
/// 여기서 대신 그리면 카드·버튼의 서로 다른 오프셋을 다시 하드코딩하게 된다.
///
/// 섀도가 없는 요소(탭 아이콘, 칩)는 [depth]를 `Offset.zero`로 두고 builder에서
/// `t`로 다른 표현(아주 약한 축소 등)을 만든다.
class LqPressable extends StatefulWidget {
  const LqPressable({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.depth = Offset.zero,
    this.behavior = HitTestBehavior.opaque,
  });

  /// `t`는 눌린 진행도(0~1)다.
  final Widget Function(BuildContext context, double t) builder;

  /// null이면 눌림 상태로 진입하지 않는다 — 비활성 요소가 반응하면 눌리는데
  /// 아무 일도 없는 것으로 읽혀 고장처럼 보인다.
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 완전히 눌렸을 때 내려가는 거리. 섀도가 있는 표면은
  /// `LqShape.pressDepth(섀도)`를 쓴다.
  final Offset depth;

  final HitTestBehavior behavior;

  bool get _enabled => onTap != null || onLongPress != null;

  @override
  State<LqPressable> createState() => _LqPressableState();
}

class _LqPressableState extends State<LqPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget._enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(LqPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 눌린 채로 비활성이 되면(전송 중 등) 눌린 모양이 남는다.
    if (!widget._enabled && _pressed) {
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _setPressed(true),
      // 스크롤로 손가락이 빠져나가면 onTapCancel이 온다. 목록 안에서 드래그할 때
      // 카드가 눌린 채 남지 않는 것은 이 두 줄 덕분이다.
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: _pressed ? 1 : 0),
        duration: LqMotion.of(context, LqMotion.press),
        curve: LqMotion.standard,
        builder: (context, t, _) {
          final child = widget.builder(context, t);
          if (widget.depth == Offset.zero) return child;
          return Transform.translate(offset: widget.depth * t, child: child);
        },
      ),
    );
  }
}
