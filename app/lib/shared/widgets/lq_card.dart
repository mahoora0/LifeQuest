import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_dashed.dart';

/// 시안의 기본 표면 — ink 2px 테두리 + 좌우 비대칭 라운드 + blur 없는 오프셋 섀도.
///
/// [locked]를 켜면 잠김/비어있음 변형(점선 테두리 + `lockedBg`, 섀도 없음)이 된다.
/// [header]를 주면 시안의 제목 띠(카드 상단 + 하단 ink 실선)가 붙고, 본문에만 [padding]이 적용된다.
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
    this.header,
    this.headerTrailing,
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

  /// 카드 상단 제목 띠. 시안의 성장 기록·내 배지·나의 기록이 모두 이 구조를 쓴다.
  final String? header;

  /// 제목 띠 우측에 붙는 보조 요소("더보기 ›" 같은).
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final effectiveBackground = locked ? LqColors.lockedBg : background;

    // 제목 띠가 붙으면 본문에만 패딩을 주고, 띠와 본문을 라운드 안쪽으로 잘라낸다.
    final Widget body = header == null
        ? child
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: LqColors.ink,
                      width: LqShape.borderWidth,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      header!,
                      style: LqText.cardTitle.copyWith(fontSize: 16),
                    ),
                    if (headerTrailing != null) ...[
                      const Spacer(),
                      headerTrailing!,
                    ],
                  ],
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          );

    Widget surface = Container(
      width: width,
      height: height,
      alignment: alignment,
      padding: header == null ? padding : null,
      clipBehavior: header == null ? Clip.none : Clip.antiAlias,
      decoration: BoxDecoration(
        color: effectiveBackground,
        borderRadius: radius,
        border: locked
            ? null
            : Border.all(color: borderColor, width: LqShape.borderWidth),
        boxShadow: (shadow && !locked) ? LqShape.cardShadow : null,
      ),
      child: body,
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
