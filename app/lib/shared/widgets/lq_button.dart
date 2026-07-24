import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 풀폭 주 버튼.
///
/// enabled: `primary` 배경 + `#FEF8EE` 글자 + 오프셋 섀도.
/// disabled: `#E3DCC8` 배경 + `textMuted` 글자, 섀도 없음.
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

  bool get _enabled => onPressed != null && !busy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _enabled ? onPressed : null,
      child: Container(
        height: height,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _enabled ? background : LqColors.disabledBg,
          borderRadius: LqShape.buttonRadius,
          border: Border.all(color: LqColors.ink, width: LqShape.borderWidth),
          boxShadow: _enabled ? LqShape.buttonShadow : null,
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
    );
  }
}
