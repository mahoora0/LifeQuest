import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 캐릭터·아이콘 PNG 표시 위젯.
///
/// 디자인 프로젝트의 PNG가 아직 `app/assets/images/`에 배치되지 않은 상태에서도
/// 레이아웃이 무너지지 않도록, 로딩 실패 시 같은 크기의 유기적 블롭으로 폴백한다.
class LqImage extends StatelessWidget {
  const LqImage(
    this.asset, {
    super.key,
    required this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.fallbackColor = LqColors.lockedTile,
    this.fallbackShape = LqImageFallbackShape.blob,
  });

  final String asset;
  final double width;
  final double? height;
  final BoxFit fit;
  final Color fallbackColor;
  final LqImageFallbackShape fallbackShape;

  @override
  Widget build(BuildContext context) {
    final resolvedHeight = height ?? width;
    return Image.asset(
      asset,
      width: width,
      height: resolvedHeight,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _Fallback(
        width: width,
        height: resolvedHeight,
        color: fallbackColor,
        shape: fallbackShape,
      ),
    );
  }
}

enum LqImageFallbackShape { blob, circle }

class _Fallback extends StatelessWidget {
  const _Fallback({
    required this.width,
    required this.height,
    required this.color,
    required this.shape,
  });

  final double width;
  final double height;
  final Color color;
  final LqImageFallbackShape shape;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: LqColors.borderMuted, width: 2),
        borderRadius: switch (shape) {
          LqImageFallbackShape.circle => BorderRadius.circular(width),
          LqImageFallbackShape.blob => BorderRadius.only(
            topLeft: Radius.elliptical(width * 0.5, height * 0.42),
            topRight: Radius.elliptical(width * 0.42, height * 0.5),
            bottomRight: Radius.elliptical(width * 0.5, height * 0.42),
            bottomLeft: Radius.elliptical(width * 0.42, height * 0.5),
          ),
        },
      ),
    );
  }
}
