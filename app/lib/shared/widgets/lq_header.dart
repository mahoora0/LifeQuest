import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 커스텀 헤더 — Material `AppBar`는 스타일이 맞지 않아 사용하지 않는다.
///
/// 뒤로가기(←) · 중앙 타이틀 · 우측 액션 구조.
class LqHeader extends StatelessWidget {
  const LqHeader({
    super.key,
    this.title,
    this.showBack = true,
    this.onBack,
    this.trailing,
  });

  final String? title;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Stack(
        children: [
          if (title != null)
            Positioned.fill(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 56),
                  child: Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LqText.screenTitle,
                  ),
                ),
              ),
            ),
          if (showBack)
            Align(
              alignment: Alignment.centerLeft,
              child: LqIconButton(
                icon: Icons.arrow_back,
                onTap: onBack ?? () => _pop(context),
                semanticLabel: '뒤로 가기',
              ),
            ),
          if (trailing != null)
            Align(alignment: Alignment.centerRight, child: trailing!),
        ],
      ),
    );
  }

  static void _pop(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}

/// 헤더·카드 우상단에 쓰는 ink 테두리 정사각 아이콘 버튼(최소 터치 타깃 44 확보).
class LqIconButton extends StatelessWidget {
  const LqIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 30,
    this.iconSize = 17,
    this.background = LqColors.card,
    this.showDot = false,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color background;

  /// 우상단 알림 점(accent).
  final bool showDot;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: LqSpacing.minTouchTarget,
          height: LqSpacing.minTouchTarget,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: LqShape.tileRadius,
                    border: Border.all(
                      color: LqColors.ink,
                      width: LqShape.borderWidth,
                    ),
                  ),
                  child: Icon(icon, size: iconSize, color: LqColors.ink),
                ),
                if (showDot)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: LqColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: LqColors.surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
