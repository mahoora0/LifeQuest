import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/friends/application/friend_providers.dart';
import 'package:life_quest/features/friends/data/friend_dto.dart';
import 'package:life_quest/features/friends/presentation/widgets/friend_widgets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_dashed.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

/// S-21 동료 여정 비교 (화면맵 2h).
///
/// 친구 행·랭킹 행 전체를 눌러 연다. 순위표가 아니라 "나란히 보기" — 앞선 쪽을
/// 골드, 나를 그린으로 두어 우열이 아니라 대조로 읽히게 한다.
class FriendJourneyScreen extends ConsumerWidget {
  const FriendJourneyScreen({super.key, required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(friendJourneyProvider(userId));
    final nickname = journey.value?.nickname;

    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 이름을 아직 모르는 동안에도 헤더는 남아야 돌아갈 길이 생긴다.
            LqHeader(title: nickname == null ? '동료의 여정' : '$nickname님의 여정'),
            Expanded(
              child: LqAsyncView<FriendJourney>(
                value: journey,
                onRetry: () => ref.invalidate(friendJourneyProvider(userId)),
                notReadyMessage: '동료의 여정은 아직 준비 중이에요',
                notReadyHint: '친구 목록에서 오늘 진행도는 볼 수 있어요.',
                data: (value) => _Body(userId: userId, journey: value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.userId, required this.journey});

  /// 라우트가 준 대상 id. **프로바이더 접근은 반드시 이 값으로 한다.**
  ///
  /// 응답 본문의 `journey.userId`를 쓰면 서버가 그 필드를 빠뜨렸을 때 0으로 떨어져
  /// 엉뚱한 family 인스턴스를 잡는다. 동료 해제는 되돌릴 수 없으므로 다른 상대에게
  /// 나가면 복구할 방법이 없다.
  final int userId;

  final FriendJourney journey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        LqSpacing.screen,
        0,
        LqSpacing.screen,
        24,
      ),
      children: [
        _ProfileRow(journey: journey),
        const SizedBox(height: LqSpacing.gap),
        _SideBySideCard(journey: journey),
        if (journey.badges.isNotEmpty) ...[
          const SizedBox(height: LqSpacing.gap),
          _BadgeCard(nickname: journey.nickname, badges: journey.badges),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: LqButton(
                label: journey.cheered ? '오늘은 응원했어요' : '응원 보내기',
                height: 46,
                fontSize: 16,
                background: LqColors.surfacePanel,
                foreground: LqColors.primary,
                // 되돌릴 수 없는 단방향 동작이라 누른 뒤에는 비활성으로 남는다.
                onPressed: journey.cheered ? null : () => _cheer(context, ref),
              ),
            ),
            const SizedBox(width: 9),
            SizedBox(
              width: 110,
              child: LqButton(
                label: '친구 삭제',
                height: 46,
                fontSize: 16,
                background: LqColors.surfacePanel,
                foreground: LqColors.textMuted,
                borderColor: LqColors.borderMuted,
                shadow: false,
                onPressed: () => _confirmUnfriend(context, ref),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _cheer(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(friendJourneyProvider(userId).notifier).cheer();
      if (context.mounted) showLqSnack(context, '응원을 보냈어요 · EXP 5');
    } catch (error) {
      if (context.mounted) showLqError(context, error);
    }
  }

  /// 친구 삭제는 되돌릴 수 없으므로 한 번 묻는다.
  Future<void> _confirmUnfriend(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: LqColors.surfacePanel,
        shape: const RoundedRectangleBorder(borderRadius: LqShape.cardRadius),
        title: Text('${journey.nickname}님과 헤어질까요?', style: LqText.cardTitle),
        content: Text(
          '서로의 여정을 더는 볼 수 없어요.\n다시 함께하려면 친구 요청을 새로 보내야 해요.',
          style: LqText.bodySm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              '그대로 둘래요',
              style: LqText.bodySm.copyWith(
                fontWeight: FontWeight.w700,
                color: LqColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '친구 삭제',
              style: LqText.bodySm.copyWith(
                fontWeight: FontWeight.w700,
                color: LqColors.dangerText,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(friendJourneyProvider(userId).notifier).unfriend();
      if (context.mounted) {
        showLqSnack(context, '${journey.nickname}님을 친구에서 삭제했어요');
        context.pop();
      }
    } catch (error) {
      if (context.mounted) showLqError(context, error);
    }
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.journey});

  final FriendJourney journey;

  @override
  Widget build(BuildContext context) {
    final title = journey.titleLine;

    return Row(
      children: [
        LqAvatar(
          nickname: journey.nickname,
          seed: journey.userId,
          size: 74,
          fontSize: 30,
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(journey.nickname, style: LqText.sectionTitle),
              if (title != null)
                Text(
                  title,
                  style: LqText.label.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: LqColors.primary,
                  ),
                ),
              Text(
                'Lv. ${journey.friend.level}',
                style: LqText.levelNumber.copyWith(height: 1),
              ),
            ],
          ),
        ),
        if (journey.cheered) ...[
          const SizedBox(width: 8),
          const LqStatePill(label: '응원함 ✓', tone: LqPillTone.gold),
        ],
      ],
    );
  }
}

class _SideBySideCard extends StatelessWidget {
  const _SideBySideCard({required this.journey});

  final FriendJourney journey;

  @override
  Widget build(BuildContext context) {
    final me = journey.me;
    final friend = journey.friend;

    return LqCard(
      header: '나란히 보기',
      headerTrailing: Text('나 · ${journey.nickname}', style: LqText.caption),
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 레벨은 서로의 값을 그대로 견주므로 두 막대가 한 트랙을 나눠 갖는다.
          _CompareHeading(label: '레벨', values: '${me.level} · ${friend.level}'),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                flex: me.level.clamp(1, 9999),
                child: const _Bar(color: LqColors.expFill),
              ),
              const SizedBox(width: 5),
              Expanded(
                flex: friend.level.clamp(1, 9999),
                child: const _Bar(color: LqColors.gold),
              ),
            ],
          ),
          const SizedBox(height: 11),
          const LqDashedDivider(color: LqColors.divider),
          const SizedBox(height: 11),
          // 서버가 공개하는 누적 EXP를 같은 기준으로 비교한다.
          _CompareHeading(
            label: '누적 EXP',
            values: '${me.totalExp} · ${friend.totalExp}',
          ),
          const SizedBox(height: 4),
          _TrackBar(
            value: me.totalExp,
            total: me.totalExp > friend.totalExp
                ? me.totalExp
                : friend.totalExp,
            color: LqColors.expFill,
          ),
          const SizedBox(height: 4),
          _TrackBar(
            value: friend.totalExp,
            total: me.totalExp > friend.totalExp
                ? me.totalExp
                : friend.totalExp,
            color: LqColors.gold,
          ),
          const SizedBox(height: 11),
          const LqDashedDivider(color: LqColors.divider),
          const SizedBox(height: 11),
          _StatRow(me: me, friend: friend),
        ],
      ),
    );
  }
}

class _CompareHeading extends StatelessWidget {
  const _CompareHeading({required this.label, required this.values});

  final String label;
  final String values;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: LqText.label.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Text(values, style: LqText.label),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.color, this.filled = true});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: LqSpacing.progressHeight,
      decoration: BoxDecoration(
        color: color,
        borderRadius: LqShape.pillRadius,
        border: Border.all(
          color: filled ? LqColors.ink : LqColors.borderMuted,
          width: LqShape.borderWidth,
        ),
      ),
    );
  }
}

/// 채운 만큼과 남은 만큼을 한 줄에 그린다.
class _TrackBar extends StatelessWidget {
  const _TrackBar({
    required this.value,
    required this.total,
    required this.color,
  });

  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final safeTotal = total <= 0 ? 1 : total;
    final filled = value.clamp(0, safeTotal);
    final rest = safeTotal - filled;

    return Semantics(
      label: '$safeTotal개 중 $filled개',
      child: Row(
        children: [
          if (filled > 0)
            Expanded(
              flex: filled,
              child: _Bar(color: color),
            ),
          if (filled > 0 && rest > 0) const SizedBox(width: 5),
          if (rest > 0)
            Expanded(
              flex: rest,
              child: const _Bar(color: LqColors.surfacePanel, filled: false),
            ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.me, required this.friend});

  final JourneySide me;
  final JourneySide friend;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: '완료 퀘스트',
              value:
                  '${me.completedQuestCount} · ${friend.completedQuestCount}',
            ),
          ),
          const LqDashedDivider(axis: Axis.vertical, color: LqColors.divider),
          Expanded(
            child: _Stat(
              label: '방문 장소',
              value: '${me.visitedPlaceCount} · ${friend.visitedPlaceCount}',
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: LqText.caption),
        Text(
          value,
          style: LqText.sectionTitle.copyWith(fontSize: 20, height: 1.2),
        ),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.nickname, required this.badges});

  final String nickname;
  final List<JourneyBadge> badges;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      header: '$nickname님의 대표 배지',
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      // 배지 개수는 서버가 정한다. 한 줄에 고정하면 여섯 칸을 넘는 순간 넘치므로
      // 줄바꿈으로 받는다.
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < badges.length; i++)
            // 첫 칸이 대표 배지다. 마이페이지 배지 칸과 같은 gold 언어를 쓴다.
            _BadgeSlot(badge: badges[i], representative: i == 0),
        ],
      ),
    );
  }
}

class _BadgeSlot extends StatelessWidget {
  const _BadgeSlot({required this.badge, required this.representative});

  final JourneyBadge badge;
  final bool representative;

  @override
  Widget build(BuildContext context) {
    final asset = badge.iconAsset;

    return Semantics(
      // 색만으로 대표를 구분하면 읽어 주는 화면에서는 전달되지 않는다.
      label: representative ? '대표 배지 ${badge.name}' : badge.name,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: representative ? LqColors.gold : LqColors.tileFill,
          borderRadius: LqShape.tileRadius,
          border: Border.all(color: LqColors.ink, width: LqShape.borderWidth),
        ),
        child: asset == null
            ? Text(
                // 서버가 이름을 빈 문자열로 주면 `characters.first`가 던진다.
                // 다른 배지 칸(마이페이지·업적)과 같은 대체 글자를 쓴다.
                badge.name.isEmpty ? '?' : badge.name.characters.first,
                style: LqText.badge.copyWith(
                  fontSize: 17,
                  color: representative
                      ? LqColors.goldText
                      : LqColors.textPrimary,
                ),
              )
            : LqImage(asset, width: 26),
      ),
    );
  }
}
