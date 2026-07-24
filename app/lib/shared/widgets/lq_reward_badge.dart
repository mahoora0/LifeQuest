import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 보상·분류 pill 뱃지.
///
/// `EXP 40`(expBadge 배경) · `G 20`(goldBg + goldBorder) · `위치 인증`(locBg).
class LqRewardBadge extends StatelessWidget {
  const LqRewardBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.border,
    this.fontSize = 11,
  });

  /// EXP 뱃지 — 항상 노출.
  factory LqRewardBadge.exp(int amount) => LqRewardBadge(
    label: 'EXP $amount',
    background: LqColors.expBadge,
    foreground: LqColors.onDark,
  );

  /// 골드 뱃지 — v1은 서버에 재화가 없어 미노출(`LqFeatures.currencyEnabled`).
  factory LqRewardBadge.gold(int amount) => LqRewardBadge(
    label: 'G $amount',
    background: LqColors.goldBg,
    foreground: LqColors.goldText,
    border: LqColors.goldBorder,
  );

  /// 위치 인증 필요 표시.
  factory LqRewardBadge.location([String label = '위치 인증']) => LqRewardBadge(
    label: label,
    background: LqColors.locBg,
    foreground: LqColors.ink,
    border: LqColors.locBorder,
  );

  /// 퀘스트 분류 태그.
  factory LqRewardBadge.tag(LqTagPalette palette) => LqRewardBadge(
    label: palette.label,
    background: palette.background,
    foreground: LqColors.textPrimary,
    border: palette.border,
    fontSize: 12,
  );

  final String label;
  final Color background;
  final Color foreground;
  final Color? border;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2.5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: LqShape.pillRadius,
        border: border == null ? null : Border.all(color: border!, width: 1.6),
      ),
      child: Text(
        label,
        style: LqText.badge.copyWith(fontSize: fontSize, color: foreground),
      ),
    );
  }
}

/// 기울어진 "도장" 표시(업적 완료·완료 결과 헤더).
class LqStamp extends StatelessWidget {
  const LqStamp({
    super.key,
    required this.label,
    this.angleDegrees = -6,
    this.color = LqColors.goldStamp,
    this.borderColor = LqColors.goldBorder,
    this.fontSize = 13,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
  });

  final String label;
  final double angleDegrees;
  final Color color;
  final Color borderColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angleDegrees * 3.1415926535 / 180,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: LqShape.tileRadius,
          border: Border.all(color: borderColor, width: LqShape.borderWidth),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: color,
          ),
        ),
      ),
    );
  }
}
