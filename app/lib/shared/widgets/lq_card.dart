import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_dashed.dart';

/// 시안의 기본 표면 — ink 2px 테두리 + 좌우 비대칭 라운드 + blur 없는 오프셋 섀도.
///
/// [locked]를 켜면 잠김/비어있음 변형(점선 테두리 + `lockedBg`, 섀도 없음)이 된다.
class LqCard extends StatelessWidget {
  const LqCard({
    super.key,
    required this.child,
    this.background = LqColors.surfaceTile,
    this.padding = const EdgeInsets.all(12),
    this.radius = LqShape.cardRadius,
    this.borderColor = LqColors.ink,
    this.locked = false,
    this.shadow = true,
    this.onTap,
    this.width,
    this.height,
    this.margin,
    this.alignment,
  });

  final Widget child;
  final Color background;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;
  final Color borderColor;
  final bool locked;
  final bool shadow;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final effectiveBackground = locked ? LqColors.lockedBg : background;

    Widget surface = Container(
      width: width,
      height: height,
      alignment: alignment,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBackground,
        borderRadius: radius,
        border: locked
            ? null
            : Border.all(color: borderColor, width: LqShape.borderWidth),
        boxShadow: (shadow && !locked) ? LqShape.cardShadow : null,
      ),
      child: child,
    );

    if (locked) {
      surface = CustomPaint(
        foregroundPainter: LqDashedBorderPainter(radius: radius),
        child: surface,
      );
    }

    if (margin != null) {
      surface = Padding(padding: margin!, child: surface);
    }

    if (onTap == null) return surface;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: surface,
    );
  }
}
