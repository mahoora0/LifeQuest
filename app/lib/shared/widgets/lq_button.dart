import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_pressable.dart';

/// 풀폭 주 버튼.
///
/// enabled: `primary` 배경 + `#FEF8EE` 글자 + 오프셋 섀도.
/// disabled: `#E3DCC8` 배경 + `textMuted` 글자, 섀도 없음.
///
/// 나란히 놓인 보조·되돌릴 수 없는 액션(거절 · 동료 해제)은 [borderColor]를
/// `borderMuted`로, [shadow]를 꺼서 한 단계 뒤로 물린다. 같은 크기·같은 라운드로
/// 두 버튼을 나란히 두면 어느 쪽이 주 액션인지 읽히지 않는다.
class LqButton extends StatelessWidget {
  const LqButton({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
    this.background = LqColors.primary,
    this.foreground = LqColors.onDark,
    this.height = 50,
    this.fontSize = 17,
    this.icon,
    this.borderColor = LqColors.ink,
    this.shadow = true,
  });

  final String label;
  final VoidCallback? onPressed;

  /// 진행 중(중복 탭 방지) — 비활성 스타일 + 스피너.
  final bool busy;
  final Color background;
  final Color foreground;
  final double height;
  final double fontSize;
  final Widget? icon;

  /// 테두리 색. 보조 액션은 `borderMuted`로 물린다.
  final Color borderColor;

  /// 오프셋 섀도. 보조 액션은 끈다.
  final bool shadow;

  bool get _enabled => onPressed != null && !busy;

  @override
  Widget build(BuildContext context) {
    final hasShadow = _enabled && shadow;

    return LqPressable(
      onTap: _enabled ? onPressed : null,
      // 섀도를 끈 보조 버튼은 내려갈 자리가 없다. 대신 builder에서 아주 약하게
      // 줄여 눌린 것을 알린다.
      depth: hasShadow ? LqShape.pressDepth(LqShape.buttonShadow) : Offset.zero,
      builder: (context, t) => Transform.scale(
        scale: hasShadow ? 1 : 1 - 0.02 * t,
        child: Container(
          height: height,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _enabled ? background : LqColors.disabledBg,
            borderRadius: LqShape.buttonRadius,
            border: Border.all(color: borderColor, width: LqShape.borderWidth),
            boxShadow: hasShadow
                ? LqShape.pressShadow(LqShape.buttonShadow, t)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: LqColors.textMuted,
                  ),
                ),
                const SizedBox(width: 10),
              ] else if (icon != null) ...[
                icon!,
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: _enabled ? foreground : LqColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
