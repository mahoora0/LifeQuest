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
  ///
  /// 글자 크기를 다른 뱃지와 같게 둔다(시안은 태그만 12였다). 목록 행에서
  /// `EXP 35`·`일간`·`위치`가 한 줄에 서므로, 1pt라도 다르면 높이가 어긋나
  /// 줄이 들쭉날쭉해진다. 같은 크기면 글꼴 배율이 커져도 함께 늘어난다.
  factory LqRewardBadge.tag(LqTagPalette palette) => LqRewardBadge(
    label: palette.label,
    background: palette.background,
    foreground: LqColors.textPrimary,
    border: palette.border,
  );

  final String label;
  final Color background;
  final Color foreground;
  final Color? border;

  /// 글자 크기. 테두리 몫은 아래에서 상쇄하지만 **글자 크기 차이는 상쇄하지
  /// 않는다** — 한 줄에 나란히 놓는 뱃지끼리는 같은 값을 줘야 높이가 맞는다.
  /// 다른 값을 주는 곳(완료 결과 14, 비밀 업적 모달 13)은 모두 그 줄에서
  /// 크기가 같은 것들끼리만 서 있다.
  final double fontSize;

  /// 테두리 두께. 이 만큼이 뱃지 바깥에 더해진다.
  static const _borderWidth = 1.6;

  /// 테두리를 포함한 상하 여백. 테두리가 있는 뱃지는 그 몫을 패딩에서 빼
  /// 외곽 높이를 맞춘다 — `EXP 35`(테두리 없음)와 `위치 인증`(테두리 있음)이
  /// 나란히 놓이므로, 같은 패딩을 주면 테두리가 있는 쪽만 3.2 더 커진다.
  static const _verticalInset = 5.8;

  @override
  Widget build(BuildContext context) {
    final hasBorder = border != null;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 9,
        vertical: hasBorder ? _verticalInset - _borderWidth : _verticalInset,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: LqShape.pillRadius,
        border: hasBorder
            ? Border.all(color: border!, width: _borderWidth)
            : null,
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
