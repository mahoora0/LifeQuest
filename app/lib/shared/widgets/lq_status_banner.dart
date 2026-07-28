import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

enum LqBannerTone { success, warn, danger, neutral }

/// 상태 배너(주로 GPS 인증 화면의 상태 머신 표시).
class LqStatusBanner extends StatelessWidget {
  const LqStatusBanner({
    super.key,
    required this.tone,
    required this.message,
    this.icon,
  });

  final LqBannerTone tone;
  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      LqBannerTone.success => (LqColors.successBg, LqColors.successText),
      LqBannerTone.warn => (LqColors.warnBg, LqColors.warnText),
      LqBannerTone.danger => (LqColors.dangerBg, LqColors.dangerText),
      LqBannerTone.neutral => (LqColors.surfaceTint, LqColors.textSecondary),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: LqShape.rowRadius,
        border: Border.all(color: foreground, width: LqShape.borderWidth),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
