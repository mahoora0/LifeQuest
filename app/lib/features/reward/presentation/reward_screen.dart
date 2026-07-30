import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/features/reward/application/reward_providers.dart';
import 'package:life_quest/features/reward/data/reward_dto.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_dashed.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_progress_bar.dart';

/// S-05 레벨 · 보상 (화면맵 2c).
///
/// 마이페이지의 EXP 바에서 push로 연다. 보상 이력을 "몇 레벨에 무엇을 받았는지"로 묶어
/// 다음 관문까지의 거리를 함께 보여준다.
class RewardScreen extends ConsumerWidget {
  const RewardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(rewardOverviewProvider);

    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 탭 밖 push 화면이라 헤더의 ←가 유일한 퇴로다. 본문과 분리해 남긴다.
            const LqHeader(title: '레벨 · 보상'),
            Expanded(
              child: LqAsyncView<RewardOverview>(
                value: overview,
                onRetry: () => ref.invalidate(rewardOverviewProvider),
                notReadyMessage: '레벨 · 보상은 아직 준비 중이에요',
                notReadyHint: '레벨과 EXP는 마이페이지에서 확인할 수 있어요.',
                data: (value) => ListView(
                  padding: const EdgeInsets.fromLTRB(
                    LqSpacing.screen,
                    4,
                    LqSpacing.screen,
                    24,
                  ),
                  children: [
                    _LevelCard(overview: value),
                    const SizedBox(height: LqSpacing.gap),
                    if (value.nextMilestone != null) ...[
                      _NextMilestoneCard(milestone: value.nextMilestone!),
                      const SizedBox(height: LqSpacing.gap),
                    ],
                    if (value.received.isNotEmpty) ...[
                      _ReceivedCard(rewards: value.received),
                      const SizedBox(height: LqSpacing.gap),
                    ],
                    if (value.weeklyExp.isNotEmpty)
                      _WeeklyExpCard(days: value.weeklyExp),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.overview});

  final RewardOverview overview;

  @override
  Widget build(BuildContext context) {
    final questsLeft = overview.questsToNextLevel;

    return LqCard(
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lv. ${overview.level}', style: LqText.levelNumber),
          const SizedBox(height: 3),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text:
                      'EXP ${overview.exp} / ${overview.expForNextLevel} · 다음 레벨까지 ',
                  style: LqText.bodySm,
                ),
                TextSpan(
                  text: '${overview.expToNext}',
                  style: LqText.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: LqColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          LqProgressBar(value: overview.exp, max: overview.expForNextLevel),
          // 남은 퀘스트 수는 서버 계산값이다. 없으면 문구 자체를 감춘다.
          if (questsLeft != null) ...[
            const SizedBox(height: 7),
            Text('퀘스트 $questsLeft개면 다음 레벨이에요', style: LqText.caption),
          ],
        ],
      ),
    );
  }
}

class _NextMilestoneCard extends StatelessWidget {
  const _NextMilestoneCard({required this.milestone});

  final LevelMilestone milestone;

  @override
  Widget build(BuildContext context) {
    // 재화는 서버에 개념이 없어 플래그가 켜질 때까지 감춘다(시안 §8).
    final currency = LqFeatures.currencyEnabled ? milestone.currencyLine : null;

    return LqCard(
      header: '다음 관문',
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Row(
        children: [
          _LevelMedal(level: milestone.level, locked: true),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(milestone.rewardLine, style: LqText.cardTitle),
                if (currency != null) ...[
                  const SizedBox(height: 2),
                  Text(currency, style: LqText.caption),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: LqColors.lockedTile,
              borderRadius: LqShape.pillRadius,
              border: Border.all(
                color: LqColors.borderMuted,
                width: LqShape.borderWidth,
              ),
            ),
            child: Text(
              '잠김',
              style: LqText.badge.copyWith(
                fontSize: 12,
                color: LqColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceivedCard extends StatelessWidget {
  const _ReceivedCard({required this.rewards});

  final List<ReceivedReward> rewards;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      header: '받은 보상',
      headerTrailing: Text('최근 순', style: LqText.caption),
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          for (var i = 0; i < rewards.length; i++) ...[
            // 시안의 구분선은 전부 점선이다.
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LqDashedDivider(),
              ),
            _ReceivedRow(reward: rewards[i]),
          ],
        ],
      ),
    );
  }
}

class _ReceivedRow extends StatelessWidget {
  const _ReceivedRow({required this.reward});

  final ReceivedReward reward;

  @override
  Widget build(BuildContext context) {
    final note = reward.note;

    return Row(
      children: [
        _LevelMedal(level: reward.level, locked: false),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reward.name, style: LqText.cardTitle),
              const SizedBox(height: 2),
              Text(
                note == null
                    ? '${reward.kind.label} · ${reward.timeLabel}'
                    : '${reward.kind.label} · ${reward.timeLabel} · $note',
                style: LqText.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 레벨 표식 — 받은 보상은 골드, 아직 닿지 않은 관문은 잠김 톤.
class _LevelMedal extends StatelessWidget {
  const _LevelMedal({required this.level, required this.locked});

  final int level;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: locked ? LqColors.lockedTile : LqColors.goldBg,
        shape: BoxShape.circle,
        border: Border.all(
          color: locked ? LqColors.borderMuted : LqColors.goldBorder,
          width: LqShape.borderWidth,
        ),
      ),
      child: Text(
        '$level',
        style: LqText.badge.copyWith(
          fontSize: 14,
          color: locked ? LqColors.textSecondary : LqColors.goldText,
        ),
      ),
    );
  }
}

/// 이번 주 EXP — 요일별 막대.
class _WeeklyExpCard extends StatelessWidget {
  const _WeeklyExpCard({required this.days});

  final List<DailyExp> days;

  @override
  Widget build(BuildContext context) {
    final peak = days.fold<int>(0, (max, day) => day.exp > max ? day.exp : max);

    return LqCard(
      header: '이번 주 EXP',
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        children: [
          SizedBox(
            height: 74,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final day in days)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _ExpBar(exp: day.exp, peak: peak),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              for (final day in days)
                Expanded(
                  child: Text(
                    day.dayLabel,
                    textAlign: TextAlign.center,
                    style: LqText.caption.copyWith(fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpBar extends StatelessWidget {
  const _ExpBar({required this.exp, required this.peak});

  final int exp;
  final int peak;

  @override
  Widget build(BuildContext context) {
    // 최고치를 100%로 두고 비율을 잡는다. 0이어도 테두리는 보이게 최소 높이를 준다.
    final ratio = peak <= 0 ? 0.0 : exp / peak;

    return Semantics(
      label: 'EXP $exp',
      child: FractionallySizedBox(
        alignment: Alignment.bottomCenter,
        heightFactor: ratio.clamp(0.08, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: exp == 0 ? LqColors.lockedTile : LqColors.expFill,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(6),
              bottom: Radius.circular(3),
            ),
            border: Border.all(color: LqColors.ink, width: 1.6),
          ),
        ),
      ),
    );
  }
}
