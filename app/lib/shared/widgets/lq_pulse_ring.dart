import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 현재 위치·목표 지점을 강조하는 펄스 링(기본 1.8s).
///
/// GPS 인증 레이더(S-10)와 지역 지도(S-11)가 함께 쓴다.
class LqPulseRing extends StatefulWidget {
  const LqPulseRing({
    super.key,
    this.minSize = 44,
    this.maxSize = 136,
    this.color = LqColors.accent,
    this.duration = const Duration(milliseconds: 1800),
  });

  final double minSize;
  final double maxSize;
  final Color color;
  final Duration duration;

  @override
  State<LqPulseRing> createState() => _LqPulseRingState();
}

class _LqPulseRingState extends State<LqPulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final size =
              widget.minSize + (widget.maxSize - widget.minSize) * t;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.color.withValues(alpha: (1 - t) * 0.55),
                width: 2,
              ),
            ),
          );
        },
      ),
    );
  }
}
