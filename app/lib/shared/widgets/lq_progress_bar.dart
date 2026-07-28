import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 진행 바 — 높이 12, ink 2px 테두리, pill, 값 변화 시 500ms ease-out 애니메이션.
class LqProgressBar extends StatelessWidget {
  const LqProgressBar({
    super.key,
    required this.value,
    required this.max,
    this.height = LqSpacing.progressHeight,
    this.fillColor = LqColors.expFill,
    this.trackColor = LqColors.surfaceRaised,
    this.borderWidth = LqShape.borderWidth,
  });

  final num value;
  final num max;
  final double height;
  final Color fillColor;
  final Color trackColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0).toDouble();

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: ratio),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, animated, _) => Container(
        height: height,
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: LqShape.pillRadius,
          border: Border.all(color: LqColors.ink, width: borderWidth),
        ),
        child: ClipRRect(
          borderRadius: LqShape.pillRadius,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: animated,
              child: DecoratedBox(
                decoration: BoxDecoration(color: fillColor),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
