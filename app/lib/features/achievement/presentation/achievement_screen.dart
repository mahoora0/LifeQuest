import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/features/achievement/application/achievement_providers.dart';
import 'package:life_quest/features/achievement/data/achievement_dto.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
import 'package:life_quest/features/user/data/user_dto.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_chip.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_progress_bar.dart';
import 'package:life_quest/shared/widgets/lq_reward_badge.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

/// S-15 업적 / S-16 칭호.
///
/// 대표 지정이 가능한 칭호 컬렉션을 업적과 한 화면에 모은다.
/// 마이페이지에서는 "나의 기록" 카드가 이 화면의 유일한 진입점이다.
class AchievementScreen extends ConsumerStatefulWidget {
  const AchievementScreen({super.key, this.initialTab = 0});

  /// 0 = 업적, 1 = 칭호.
  final int initialTab;

  @override
  ConsumerState<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends ConsumerState<AchievementScreen> {
  late int _tab = widget.initialTab;
  AchievementFilter _filter = AchievementFilter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        child: Column(
          children: [
            const LqHeader(title: '업적 / 칭호'),
            _TabBar(
              current: _tab,
              onChanged: (index) => setState(() => _tab = index),
            ),
            Expanded(
              child: switch (_tab) {
                0 => _AchievementTab(
                  filter: _filter,
                  onFilterChanged: (filter) => setState(() => _filter = filter),
                ),
                _ => const _TitleTab(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.current, required this.onChanged});

  final int current;
  final ValueChanged<int> onChanged;

  static const _labels = ['업적', '칭호'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: Container(
                height: LqSpacing.minTouchTarget,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: i == current
                          ? LqColors.primary
                          : LqColors.borderMuted,
                      width: i == current ? 3 : 1.5,
                    ),
                  ),
                ),
                child: Text(
                  _labels[i],
                  style: LqText.cardTitle.copyWith(
                    color: i == current
                        ? LqColors.primary
                        : LqColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AchievementTab extends ConsumerWidget {
  const _AchievementTab({required this.filter, required this.onFilterChanged});

  final AchievementFilter filter;
  final ValueChanged<AchievementFilter> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(achievementOverviewProvider);

    return LqAsyncView<AchievementOverview>(
      value: overview,
      isEmpty: (value) => value.isEmpty,
      emptyMessage: '아직 등록된 업적이 없어요',
      // 업적 목록만 서버가 없고 칭호는 조회된다. 첫 탭이 오류로 막히면
      // 동작하는 두 탭까지 함께 죽은 것처럼 보이므로 그쪽으로 안내한다.
      notReadyMessage: '업적 목록은 아직 준비 중이에요',
      notReadyHint: '칭호는 지금도 확인할 수 있어요.',
      onRetry: () => ref.invalidate(achievementOverviewProvider),
      data: (value) {
        final visible = value.achievements.where(filter.matches).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            LqSpacing.screen,
            LqSpacing.gap,
            LqSpacing.screen,
            24,
          ),
          children: [
            _SummaryCard(overview: value),
            const SizedBox(height: LqSpacing.gap),
            LqChipRow(
              padding: EdgeInsets.zero,
              labels: [
                for (final value in AchievementFilter.values) value.label,
              ],
              selectedIndex: AchievementFilter.values.indexOf(filter),
              onSelected: (index) =>
                  onFilterChanged(AchievementFilter.values[index]),
            ),
            const SizedBox(height: 4),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: LqEmptyView(message: '이 조건에 맞는 업적이 없어요'),
              )
            else
              for (final achievement in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AchievementRow(achievement: achievement),
                ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.overview});

  final AchievementOverview overview;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          // 트로피 도형 — 아이콘 대신 시안의 도형 언어로 그린다.
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LqColors.goldBg,
              borderRadius: LqShape.tileRadius,
              border: Border.all(
                color: LqColors.goldBorder,
                width: LqShape.borderWidth,
              ),
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              size: 24,
              color: LqColors.goldText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('달성한 업적', style: LqText.label),
                const SizedBox(height: 2),
                Text(
                  '${overview.achievedCount} / ${overview.total}',
                  style: LqText.levelNumber,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final hidden = achievement.isHiddenSecret;

    return LqCard(
      radius: LqShape.rowRadius,
      locked: hidden,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hidden
                  ? LqColors.lockedTile
                  : achievement.achieved
                  ? LqColors.goldBg
                  : LqColors.surfaceTint,
              border: Border.all(
                color: hidden ? LqColors.borderMuted : LqColors.ink,
                width: LqShape.borderWidth,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.elliptical(20, 16),
                topRight: Radius.elliptical(16, 20),
                bottomRight: Radius.elliptical(20, 16),
                bottomLeft: Radius.elliptical(16, 20),
              ),
            ),
            child: hidden
                ? Text(
                    '?',
                    style: LqText.cardTitle.copyWith(color: LqColors.textMuted),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // 비밀 업적의 마스킹 값은 서버가 준 그대로 표시한다.
                  hidden && achievement.name.isEmpty
                      ? '비밀 업적'
                      : achievement.name,
                  style: LqText.cardTitle.copyWith(
                    color: hidden ? LqColors.textMuted : LqColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  achievement.condition ??
                      (hidden ? '조건을 달성하면 공개돼요' : '조건을 달성해 보세요'),
                  style: LqText.caption,
                ),
                if (achievement.currentStep != null &&
                    achievement.currentStep! > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    '현재 ${achievement.currentStep}단계',
                    style: LqText.caption.copyWith(color: LqColors.primary),
                  ),
                ],
                if (achievement.hasProgress) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: LqProgressBar(
                          value: achievement.currentValue!,
                          max: achievement.requiredValue!,
                          height: 9,
                          borderWidth: 1.6,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${achievement.currentValue}/${achievement.requiredValue}',
                        style: LqText.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ],
                if (!achievement.achieved && achievement.expReward != null) ...[
                  const SizedBox(height: 6),
                  LqRewardBadge.exp(achievement.expReward!),
                ],
              ],
            ),
          ),
          if (achievement.achieved) ...[
            const SizedBox(width: 8),
            const LqStamp(label: '완료'),
          ],
        ],
      ),
    );
  }
}

class _TitleTab extends ConsumerWidget {
  const _TitleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titles = ref.watch(titleCollectionProvider);

    return LqAsyncView<TitleCollection>(
      value: titles,
      isEmpty: (value) => value.titles.isEmpty,
      emptyMessage: '아직 획득한 칭호가 없어요',
      onRetry: () => ref.invalidate(titleCollectionProvider),
      data: (value) => ListView(
        padding: const EdgeInsets.fromLTRB(
          LqSpacing.screen,
          LqSpacing.gap,
          LqSpacing.screen,
          24,
        ),
        children: [
          Text('탭하면 대표 칭호로 지정돼요 — 다시 누르면 해제됩니다', style: LqText.caption),
          const SizedBox(height: 10),
          for (final title in value.titles)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TitleRow(
                title: title,
                selected: value.representativeTitleId == title.id,
                onTap: () => _select(context, ref, title.id),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _select(BuildContext context, WidgetRef ref, int titleId) async {
    try {
      await ref.read(titleCollectionProvider.notifier).select(titleId);
    } catch (error) {
      if (!context.mounted) return;
      showLqError(context, error);
    }
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final UserTitle title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      radius: LqShape.rowRadius,
      background: selected ? LqColors.surfaceTint : LqColors.surfaceRaised,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.name, style: LqText.cardTitle),
                if (title.description != null) ...[
                  const SizedBox(height: 3),
                  Text(title.description!, style: LqText.caption),
                ],
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle, size: 22, color: LqColors.primary),
        ],
      ),
    );
  }
}
