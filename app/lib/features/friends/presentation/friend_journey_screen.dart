import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/friends/application/friend_providers.dart';
import 'package:life_quest/features/friends/data/friend_dto.dart';
import 'package:life_quest/features/friends/presentation/widgets/friend_widgets.dart';
import 'package:life_quest/shared/design/lq_hero_tags.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
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
        _ComparisonSection(journey: journey),
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
          heroTag: LqHeroTags.adventurer(journey.userId),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                journey.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LqText.sectionTitle,
              ),
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

class _ComparisonSection extends StatelessWidget {
  const _ComparisonSection({required this.journey});

  final FriendJourney journey;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text('여정 비교', style: LqText.cardTitle),
            const Spacer(),
            const _Legend(color: LqColors.expFill, label: '나'),
            const SizedBox(width: 10),
            _Legend(color: LqColors.gold, label: journey.nickname),
          ],
        ),
        const SizedBox(height: 8),
        _ComparisonCard(
          label: '레벨',
          unit: 'Lv.',
          mine: journey.me.level,
          theirs: journey.friend.level,
        ),
        const SizedBox(height: 9),
        _ComparisonCard(
          label: '누적 EXP',
          unit: ' EXP',
          mine: journey.me.totalExp,
          theirs: journey.friend.totalExp,
        ),
        const SizedBox(height: 9),
        _ComparisonCard(
          label: '업적',
          unit: '개',
          mine: journey.me.completedQuestCount,
          theirs: journey.friend.completedQuestCount,
          total: _total(
            journey.me.achievementTotal,
            journey.friend.achievementTotal,
          ),
        ),
        const SizedBox(height: 9),
        _ComparisonCard(
          label: '도감',
          unit: '개',
          mine: journey.me.visitedPlaceCount,
          theirs: journey.friend.visitedPlaceCount,
          total: _total(journey.me.lifedexTotal, journey.friend.lifedexTotal),
        ),
        const SizedBox(height: 9),
        _TitleCard(nickname: journey.nickname, title: journey.titleLine),
      ],
    );
  }

  int? _total(int mine, int theirs) =>
      mine > 0 || theirs > 0 ? (mine > theirs ? mine : theirs) : null;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 80),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LqText.caption,
          ),
        ),
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.label,
    required this.unit,
    required this.mine,
    required this.theirs,
    this.total,
  });
  final String label;
  final String unit;
  final int mine;
  final int theirs;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final difference = theirs - mine;
    final maximum = total ?? (mine > theirs ? mine : theirs);
    final safeMaximum = maximum <= 0 ? 1 : maximum;
    final differenceLabel = difference == 0
        ? '동일'
        : difference > 0
        ? '+${difference.abs()}$unit'
        : '나 +${difference.abs()}$unit';
    return LqCard(
      radius: LqShape.rowRadius,
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                label,
                style: LqText.bodySm.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: difference == 0 ? LqColors.lockedBg : LqColors.goldBg,
                  borderRadius: LqShape.pillRadius,
                ),
                child: Text(
                  differenceLabel,
                  style: LqText.badge.copyWith(
                    fontSize: 11,
                    color: difference == 0
                        ? LqColors.textMuted
                        : LqColors.goldText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _PersonProgress(
            name: '나',
            value: mine,
            total: total,
            maximum: safeMaximum,
            unit: unit,
            color: LqColors.expFill,
            leading: difference < 0,
          ),
          const SizedBox(height: 7),
          _PersonProgress(
            name: '친구',
            value: theirs,
            total: total,
            maximum: safeMaximum,
            unit: unit,
            color: LqColors.gold,
            leading: difference > 0,
          ),
        ],
      ),
    );
  }
}

class _PersonProgress extends StatelessWidget {
  const _PersonProgress({
    required this.name,
    required this.value,
    required this.total,
    required this.maximum,
    required this.unit,
    required this.color,
    required this.leading,
  });
  final String name;
  final int value;
  final int? total;
  final int maximum;
  final String unit;
  final Color color;
  final bool leading;

  @override
  Widget build(BuildContext context) {
    final valueLabel = total != null
        ? '$value / $total'
        : unit == 'Lv.'
        ? 'Lv. $value'
        : '$value$unit';
    return Semantics(
      label: '$name $valueLabel',
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              name,
              style: LqText.caption.copyWith(
                fontWeight: leading ? FontWeight.w700 : FontWeight.w400,
                color: leading ? LqColors.textPrimary : LqColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: LqShape.pillRadius,
              child: LinearProgressIndicator(
                value: (value / maximum).clamp(0.0, 1.0),
                minHeight: 9,
                backgroundColor: LqColors.lockedBg,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 72,
            child: Text(
              valueLabel,
              textAlign: TextAlign.right,
              maxLines: 1,
              style: LqText.label.copyWith(
                fontWeight: leading ? FontWeight.w700 : FontWeight.w500,
                color: LqColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleCard extends StatelessWidget {
  const _TitleCard({required this.nickname, required this.title});
  final String nickname;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final shown =
        title?.replaceFirst(RegExp(r'^칭호\s*[·:]?\s*'), '') ?? '사용 중인 칭호 없음';
    return LqCard(
      radius: LqShape.rowRadius,
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LqColors.tileFill,
              borderRadius: LqShape.tileRadius,
            ),
            child: const Icon(
              Icons.auto_awesome_outlined,
              size: 18,
              color: LqColors.goldStamp,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('사용 중인 칭호', style: LqText.caption),
                Text(
                  '$nickname · $shown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LqText.bodySm.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
