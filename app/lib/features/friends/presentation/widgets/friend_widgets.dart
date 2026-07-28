import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 아바타 원형 배경 — 시안(10번 화면)이 친구별로 지정한 4색.
/// 서버가 색을 주지 않으므로 사용자 id로 순환시켜 같은 친구는 항상 같은 색을 갖게 한다.
const lqAvatarColors = <Color>[
  Color(0xFFDCE8C6),
  Color(0xFFF0E1C4),
  Color(0xFFCFE3EC),
  Color(0xFFEADFF3),
];

Color lqAvatarColorFor(int id) =>
    lqAvatarColors[id.abs() % lqAvatarColors.length];

/// 이니셜 아바타. 친구 목록 · 동료 찾기 · 받은 요청 · 여정 비교가 크기만 달리해 함께 쓴다.
class LqAvatar extends StatelessWidget {
  const LqAvatar({
    super.key,
    required this.nickname,
    required this.seed,
    this.size = 38,
    this.fontSize = 16,
  });

  final String nickname;
  final int seed;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: lqAvatarColorFor(seed),
        shape: BoxShape.circle,
        border: Border.all(color: LqColors.ink, width: LqShape.borderWidth),
      ),
      child: Text(
        nickname.isEmpty ? '?' : nickname.characters.first,
        style: LqText.badge.copyWith(
          fontSize: fontSize,
          color: LqColors.goldText,
        ),
      ),
    );
  }
}

/// 닉네임 + 레벨 + 보조 문구 한 덩어리. 네 화면의 행이 같은 배치를 쓴다.
class LqAdventurerIdentity extends StatelessWidget {
  const LqAdventurerIdentity({
    super.key,
    required this.nickname,
    required this.level,
    this.statusLine,
    this.nameStyle,
  });

  final String nickname;
  final int level;
  final String? statusLine;
  final TextStyle? nameStyle;

  @override
  Widget build(BuildContext context) {
    final line = statusLine;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: nameStyle ?? LqText.cardTitle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Lv.$level',
              style: LqText.caption.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: LqColors.primary,
              ),
            ),
          ],
        ),
        if (line != null) ...[
          const SizedBox(height: 2),
          Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LqText.caption,
          ),
        ],
      ],
    );
  }
}

/// 행 우측의 상태 pill. 누를 수 있는 것만 primary로 도드라지게 둔다.
class LqStatePill extends StatelessWidget {
  const LqStatePill({
    super.key,
    required this.label,
    this.onTap,
    this.tone = LqPillTone.muted,
  });

  final String label;
  final VoidCallback? onTap;
  final LqPillTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border) = switch (tone) {
      LqPillTone.primary => (LqColors.primary, LqColors.onDark, LqColors.ink),
      LqPillTone.gold => (LqColors.gold, LqColors.goldText, LqColors.ink),
      LqPillTone.quiet => (
        LqColors.surfacePanel,
        LqColors.primary,
        LqColors.ink,
      ),
      LqPillTone.muted => (
        LqColors.lockedBg,
        LqColors.textMuted,
        LqColors.borderMuted,
      ),
    };

    final pill = Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: LqShape.pillRadius,
        border: Border.all(color: border, width: LqShape.borderWidth),
      ),
      child: Text(
        label,
        style: LqText.badge.copyWith(fontSize: 13, color: foreground),
      ),
    );

    if (onTap == null) return pill;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // 칩 자체는 낮으므로 래퍼로 최소 터치 타깃을 확보한다.
        child: Container(
          constraints: const BoxConstraints(
            minHeight: LqSpacing.minTouchTarget,
          ),
          alignment: Alignment.center,
          child: pill,
        ),
      ),
    );
  }
}

enum LqPillTone {
  /// 누를 수 있는 주 액션.
  primary,

  /// 완료된 단방향 동작(응원함).
  gold,

  /// 누를 수 있지만 주 액션은 아닌 것(복사).
  quiet,

  /// 누를 수 없는 상태 표시.
  muted,
}
